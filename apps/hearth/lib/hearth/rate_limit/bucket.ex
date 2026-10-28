defmodule Hearth.RateLimit.Bucket do
  use Hearth.Repo.Schema, prefix: "rate_limit", primary_key: {:key, :string, autogenerate: false}

  @limit "$2::float8"
  @scale "$3::float8"
  @cost "$4::float8"
  @refilled "LEAST(#{@limit}, b.tokens + EXTRACT(EPOCH FROM clock_timestamp() - b.refilled_at) * 1000 * #{@limit} / #{@scale})"

  # One statement so concurrent hits on a key queue on its row
  # clock_timestamp is the time now where now is when the transaction began
  @take """
  INSERT INTO rate_limit.buckets AS b (key, tokens, allowed, refilled_at, expires_at)
  VALUES (
    $1,
    CASE WHEN #{@cost} <= #{@limit} THEN #{@limit} - #{@cost} ELSE #{@limit} END,
    #{@cost} <= #{@limit},
    clock_timestamp(),
    clock_timestamp() + #{@scale} * interval '1 millisecond'
  )
  ON CONFLICT (key) DO UPDATE SET
    tokens = CASE WHEN #{@refilled} >= #{@cost} THEN #{@refilled} - #{@cost} ELSE #{@refilled} END,
    allowed = #{@refilled} >= #{@cost},
    refilled_at = clock_timestamp(),
    expires_at = clock_timestamp() + #{@scale} * interval '1 millisecond'
  RETURNING tokens, allowed
  """

  schema "buckets" do
    field :tokens, :float
    field :allowed, :boolean
    field :refilled_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec
  end

  @type t :: %__MODULE__{
          key: String.t(),
          tokens: float(),
          allowed: boolean(),
          refilled_at: DateTime.t(),
          expires_at: DateTime.t()
        }

  @spec take(term(), pos_integer(), pos_integer(), pos_integer()) ::
          {:allow, non_neg_integer()} | {:deny, non_neg_integer()}
  def take(key, scale, limit, cost) when scale > 0 and limit > 0 and cost > 0 do
    %{rows: [[tokens, allowed]]} = Repo.query!(@take, [to_string(key), limit, scale, cost])

    case allowed do
      true -> {:allow, limit - floor(tokens)}
      false -> {:deny, ceil((cost - tokens) * scale / limit)}
    end
  end

  @spec delete_full() :: non_neg_integer()
  def delete_full do
    now = DateTime.utc_now()
    query = from(b in __MODULE__, where: b.expires_at < ^now)
    {count, _rows} = Repo.delete_all(query)

    count
  end
end
