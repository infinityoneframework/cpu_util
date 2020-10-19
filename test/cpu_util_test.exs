defmodule CpuUtilTest do
  use ExUnit.Case
  doctest CpuUtil

  test "greets the world" do
    assert CpuUtil.hello() == :world
  end
end
