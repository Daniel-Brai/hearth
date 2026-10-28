defmodule Hearth.Common.MailDomainTest do
  use ExUnit.Case, async: true

  alias Hearth.Common.MailDomain

  describe "status/1" do
    test "a domain that can't exist is unreachable" do
      assert MailDomain.status("someone@typo.invalid") == :unreachable
    end

    test "assumes ok if DNS fails" do
      assert MailDomain.status("someone@example.org") == :unknown
    end
  end

  describe "address_status/1" do
    test "something that isn't an address is invalid" do
      assert MailDomain.address_status("not an email") == :invalid
    end

    test "checks the domain of a real address" do
      assert MailDomain.address_status("someone@typo.invalid") == :unreachable
    end
  end
end
