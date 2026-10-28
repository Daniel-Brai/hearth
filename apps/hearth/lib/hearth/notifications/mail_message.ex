defmodule Hearth.Notifications.MailMessage do
  # Lines added before action/3 or code/2 go above it, lines added after go below

  defstruct [
    :subject,
    :greeting,
    :preview,
    :action_text,
    :action_url,
    :code,
    level: :info,
    intro_lines: [],
    sections: [],
    outro_lines: []
  ]

  @type level :: :error | :info | :success

  @type item :: %{title: String.t(), url: String.t(), meta: String.t()}

  @type link_line :: {:link, String.t(), String.t(), String.t()}

  @type section :: %{
          heading: String.t(),
          url: String.t(),
          items: [item()],
          more: nil | {String.t(), String.t()}
        }

  @type t :: %__MODULE__{
          subject: nil | String.t(),
          greeting: nil | String.t(),
          preview: nil | String.t(),
          action_text: nil | String.t(),
          action_url: nil | String.t(),
          code: nil | String.t(),
          level: level(),
          intro_lines: [String.t() | link_line()],
          sections: [section()],
          outro_lines: [String.t() | link_line()]
        }

  @spec error(t()) :: t()
  def error(%__MODULE__{} = message), do: %{message | level: :error}

  @spec subject(t(), String.t()) :: t()
  def subject(%__MODULE__{} = message, subject), do: %{message | subject: subject}

  @spec greeting(t(), String.t()) :: t()
  def greeting(%__MODULE__{} = message, greeting), do: %{message | greeting: greeting}

  # Defaults to the first line
  @spec preview(t(), String.t()) :: t()
  def preview(%__MODULE__{} = message, preview), do: %{message | preview: preview}

  @spec action(t(), String.t(), String.t()) :: t()
  def action(%__MODULE__{} = message, text, url) do
    %{message | action_text: text, action_url: url}
  end

  @spec code(t(), String.t()) :: t()
  def code(%__MODULE__{} = message, code), do: %{message | code: code}

  @spec section(t(), section()) :: t()
  def section(%__MODULE__{} = message, %{heading: _, url: _, items: _, more: _} = section),
    do: %{message | sections: [section | message.sections]}

  @spec link_line(t(), String.t(), String.t(), String.t()) :: t()
  def link_line(%__MODULE__{} = message, before, text, url),
    do: line(message, {:link, before, text, url})

  @spec line(t(), String.t() | link_line()) :: t()
  def line(%__MODULE__{} = message, content)
      when is_binary(content) or elem(content, 0) == :link do
    case below?(message) do
      true -> %{message | outro_lines: [content | message.outro_lines]}
      false -> %{message | intro_lines: [content | message.intro_lines]}
    end
  end

  defp below?(%__MODULE__{action_text: nil, code: nil}), do: false
  defp below?(%__MODULE__{}), do: true
end
