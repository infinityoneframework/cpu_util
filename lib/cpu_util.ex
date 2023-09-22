defmodule CpuUtil do
  @moduledoc """
  CPU utility functions.

  Functions to read and calculate CPU utilization for a given process.

  NOTE: Only *nix systems supported.
  """
  require Logger

  @type proc_pid_stat :: %{
          # process id
          pid: integer(),
          # filename of the executable
          tcomm: binary(),
          # state (R is running, S is sleeping, D is sleeping in an
          # uninterruptible wait, Z is zombie, T is traced or stopped)
          state: binary(),
          # process id of the parent process
          ppid: integer(),
          # pgrp of the process
          pgrp: integer(),
          # session id
          sid: integer(),
          # tty the process uses
          tty_nr: integer(),
          # pgrp of the tty
          tty_pgrp: integer(),
          # task flags
          flags: integer(),
          # number of minor faults
          min_flt: integer(),
          # number of minor faults with child's
          cmin_flt: integer(),
          # number of major faults
          maj_flt: integer(),
          # number of major faults with child's
          cmaj_flt: integer(),
          # user mode jiffies
          utime: integer(),
          # kernel mode jiffies
          stime: integer(),
          # user mode jiffies with child's
          cutime: integer(),
          # kernel mode jiffies with child's
          cstime: integer()
        }

  @type util_stat :: %{
          stats: proc_pid_stat(),
          total: integer()
        }

  @type util :: %{
          sys: float(),
          total: float(),
          user: float()
        }

  # list of fields returned when /proc/<PID>/stat is read.
  @proc_pid_stat_fields ~w[
    pid tcomm state ppid pgrp sid tty_nr tty_pgrp flags  min_flt
    cmin_flt maj_flt cmaj_flt utime  stime cutime cstime
  ]a

  @doc """
  Get the current OS PID.

  ## Examples

      iex> CpuUtil.getpid() |> is_integer()
      true
  """
  @spec getpid() :: integer()
  def getpid, do: List.to_integer(:os.getpid())

  @doc """
  Get the number of CPU Cores.

  Deprecated! Use `CpuUtil.core_count/0` instead.
  """
  @spec num_cores() :: {:ok, integer()} | :error
  def num_cores do
    Logger.warning("deprecated. use core_count/0 instead")
    core_count()
  end

  @doc """
  Get the number of CPU Cores.

  ## Examples

      iex> {:ok, cores} = CpuUtil.core_count()
      iex> is_integer(cores)
      true
  """
  @spec core_count() :: {:ok, integer()} | :error
  def core_count do
    with topology <- :erlang.system_info(:cpu_topology),
         processors when is_list(processors) <- topology[:processor] do
      {:ok, length(processors)}
    else
      _ -> :error
    end
  end

  @doc """
  Read the CPU's average load.

  ## Examples

      iex> {float, ""} = CpuUtil.loadavg() |> Float.parse()
      iex> is_float(float)
      true
  """
  @spec loadavg(integer()) :: binary()
  def loadavg(num \\ 1) do
    with {:ok, file} <- File.read("/proc/loadavg"),
         list <- String.split(file, ~r/\s/, trim: true) do
      list |> Enum.take(num) |> Enum.join(" ")
    else
      _ -> ""
    end
  end

  @doc """
  Read the OS stat data.

  * Reads `/proc/stat`
  * Parses the first line ('cpu')
  * Converts the numbers (string) to integers

  ## Examples

      iex> ["cpu" | numbers] = CpuUtil.stat()
      iex> length(numbers) == 10 and Enum.all?(numbers, &is_integer/1)
      true
  """
  @spec stat() :: list() | {:error, any()}
  def stat do
    with {:ok, file} <- File.read("/proc/stat"), do: stat(file)
  end

  @doc """
  Parse the data read from /proc/stat.

  Extract the first line "cpu" and convert numbers to integers.

  ## Examples

    iex> CpuUtil.stat("cpu 12010882 75 3879349 1731141995 200300 225 154316 115184 0")
    ["cpu", 12010882, 75, 3879349, 1731141995, 200300, 225, 154316, 115184, 0]
  """
  @spec stat(binary) :: list() | {:error, any()}
  def stat(contents) do
    with list <- String.split(contents, "\n", trim: true),
         [cpu | _] <- list,
         [label | value] <- String.split(cpu, ~r/\s/, trim: true),
         do: [label | Enum.map(value, &String.to_integer/1)]
  end

  @doc """
  Get the total_time from the given list.

  Takes the output of CpuUtil.stat/0 and returns the total time.

  ## Examples

      iex> data = ["cpu", 12010882, 75, 3879349, 1731141995, 200300, 225, 154316, 115184, 0]
      iex> CpuUtil.stat_total_time(data)
      1747502326
  """
  @spec stat_total_time(list()) :: integer()
  def stat_total_time([_label | list]), do: Enum.sum(list)

  @doc """
  Get the total_time.

  Return the total time (from `/proc/stat`) as an integer.

  ## Examples

      iex> CpuUtil.total_time() |> is_integer()
      true
  """
  @spec total_time() :: integer()
  def total_time do
    with [_ | _] = list <- stat(), do: stat_total_time(list)
  end

  @doc """
  Get the total time given the contents of "/proc/stat"

  ## Examples

      iex> CpuUtil.total_time("cpu 12010882 75 3879349 1731141995 200300 225 154316 115184 0")
      1747502326
  """
  @spec total_time(binary()) :: integer() | float()
  def total_time(stat) when is_binary(stat) do
    stat
    |> stat()
    |> stat_total_time()
  end

  @doc """
  Get the current OS <PID> stat.

  * Read `/proc/<PID>/stat` (single line of space separated fields)
  * Parse the fields and convert any numbers (string) to integers

  Returns a map of of the fields (atom keys) per the following definition:

  *  pid           process id
  *  tcomm         filename of the executable
  *  state         state (R is running, S is sleeping, D is sleeping in an
  *                uninterruptible wait, Z is zombie, T is traced or stopped)
  *  ppid          process id of the parent process
  *  pgrp          pgrp of the process
  *  sid           session id
  *  tty_nr        tty the process uses
  *  tty_pgrp      pgrp of the tty
  *  flags         task flags
  *  min_flt       number of minor faults
  *  cmin_flt      number of minor faults with child's
  *  maj_flt       number of major faults
  *  cmaj_flt      number of major faults with child's
  *  utime         user mode jiffies
  *  stime         kernel mode jiffies
  *  cutime        user mode jiffies with child's
  *  cstime        kernel mode jiffies with child's

  ## Examples

      iex> CpuUtil.stat_pid(CpuUtil.getpid()) |> Map.keys()
      ~w(cmaj_flt cmin_flt cstime cutime flags maj_flt min_flt pgrp pid ppid sid state stime tcomm tty_nr tty_pgrp utime)a

      # iex> str = "9731 (beam.smp) S 9730 9730 9730 0 -1 4202496 13784 3143 0 0 93 11 0 0 20 0 "
      # iex> str = str <> "28 0 291467565 2993774592 15101 18446744073709551615 4194304 7475860 "
      # iex> str = str <> "140732224047216 140732224045552 256526653091 0 0 4224 16902 "
      # iex> str = str <> "18446744073709551615 0 0 17 3 0 0 0 0 0"
      iex> content = "9731 (beam.smp) S 9730 9730 9730 0 -1 4202496 13784 3143 0 0 93 11 0 0 " <>
      ...> "20 0 291467565 2993774592 15101 18446744073709551615 4194304 7475860 140732224047216 " <>
      ...> "140732224047216 140732224045552 256526653091 0 0 4224 16902 18446744073709551615 0 " <>
      ...> "0 17 3 0 0 0 0 0"
      iex> CpuUtil.stat_pid(content)
      %{
        cmaj_flt: 0,
        cmin_flt: 3143,
        cstime: 0,
        cutime: 0,
        flags: 4202496,
        maj_flt: 0,
        min_flt: 13784,
        pgrp: 9730,
        pid: 9731,
        ppid: 9730,
        sid: 9730,
        state: "S",
        stime: 11,
        tcomm: "(beam.smp)",
        tty_nr: 0,
        tty_pgrp: "-1",
        utime: 93
      }
  """
  @spec stat_pid(integer() | binary()) :: proc_pid_stat() | {:error, any()}
  def stat_pid(pid) when is_integer(pid) do
    with {:ok, file} <- File.read("/proc/#{pid}/stat"), do: stat_pid(file)
  end

  def stat_pid(contents) when is_binary(contents) do
    with list <- String.split(contents, ~r/\s/, trim: true),
         list <-
           Enum.map(list, fn item ->
             if item =~ ~r/^\d+$/, do: String.to_integer(item), else: item
           end),
         do: @proc_pid_stat_fields |> Enum.zip(list) |> Enum.into(%{})
  end

  @doc """
  Get the current OS stat.

  * Read the total time from `/proc/stat`
  * Read the PID stats from `/proc/<PID>/stat`

  Return a map:

      %{
        total: integer()
        stats: proc_pid_stat()
      }

  ## Examples

      iex> fields = ~w(cmaj_flt cmin_flt cstime cutime flags maj_flt min_flt pgrp pid ppid sid
      ...>             state stime tcomm tty_nr tty_pgrp utime)a
      iex> util = CpuUtil.pid_util(CpuUtil.getpid())
      iex> Map.keys(util) == ~w(stats total)a and is_integer(util.total) and
      ...>   Map.keys(util.stats) == fields
      true
  """
  @spec pid_util(integer) :: util_stat()
  def pid_util(pid),
    do: %{
      total: total_time(),
      stats: stat_pid(pid)
    }

  @doc """
  Calculate CPU utilization given 2 readings.

  ## Algorithm

  user_util = 100 * (utime_after - utime_before) / (time_total_after - time_total_before);
  sys_util = 100 * (stime_after - stime_before) / (time_total_after - time_total_before);

  ## Usage

      > pid = CpuUtil.os_pid()
      > cores = CpuUtil.num_cores()
      > u1 = CpuUtil.pid_util(pid)
      > Process.sleep(1000)
      > u2 = CpuUtil.pid_util(pid)
      > CpuUtil.calc_pid_util(u1, u2, cores)
      %{
         user: 2.0,
         sys: 0.5,
         total: 2.5
      }

  ## References

  * https://stackoverflow.com/questions/1420426/how-to-calculate-the-cpu-usage-of-a-process-by-pid-in-linux-from-c/1424556

  ## Examples

      iex> prev = %{total: 99, stats: %{utime: 20, stime: 10}}
      iex> curr = %{total: 248, stats: %{utime: 29, stime: 18}}
      iex> CpuUtil.calc_pid_util(prev, curr)
      %{sys: 5.4, total: 11.4, user: 6.0}

      iex> prev = %{total: 99, stats: %{utime: 20, stime: 10}}
      iex> curr = %{total: 248, stats: %{utime: 29, stime: 18}}
      iex> CpuUtil.calc_pid_util(prev, curr, 2, 2)
      %{sys: 10.74, total: 22.82, user: 12.08}
  """
  def calc_pid_util(prev, curr, cores \\ 1, precision \\ 1) do
    try do
      t_diff = curr.total - prev.total

      {user_util, sys_util} = calc_user_sys_util(t_diff, curr, prev, cores)

      %{
        sys: Float.round(sys_util, precision),
        total: Float.round(user_util + sys_util, precision),
        user: Float.round(user_util, precision)
      }
    rescue
      _e -> %{sys: 0.0, total: 0.0, user: 0.0}
    end
  end

  defp calc_user_sys_util(0, _, _, _),
    do: {0, 0}

  defp calc_user_sys_util(t_diff, curr, prev, cores),
    do:
      {100 * (curr.stats.utime - prev.stats.utime) / t_diff * cores,
       100 * (curr.stats.stime - prev.stats.stime) / t_diff * cores}

  @doc """
  Calculate the OS process CPU Utilization.

  Similar to `CpuUtil.calc_pid_util/4` except that it takes the raw binary data
  read from `{"/proc/stat", "/proc/<os_pid>/stat"}`.

  ## Examples

      iex> prev = {"cpu  11380053 51 3665881 1638097578 194367 213 149713 110770 0",
      ...> "9930 (beam.smp) S 24113 9930 24113 34817 9930 4202496 189946 5826 0 0 12025 1926 " <>
      ...> "0 0 20 0 28 0 275236728 3164401664 42600 18446744073709551615 4194304 7475860 " <>
      ...> "140732561929584 140732561927920 256526653091 0 0 4224 134365702 18446744073709551615 " <>
      ...> "0 0 17 3 0 0 0 0 0"}
      iex> curr = {"cpu  11380060 51 3665883 1638099001 194367 213 149713 110770 0",
      ...> "9930 (beam.smp) S 24113 9930 24113 34817 9930 4202496 189950 5826 0 0 12027 1927 " <>
      ...> "0 0 20 0 28 0 275236728 3164401664 42600 18446744073709551615 4194304 7475860 " <>
      ...> "140732561929584 140732561927920 256526653091 0 0 4224 134365702 18446744073709551615 " <>
      ...> "0 0 17 3 0 0 0 0 0"}
      iex> CpuUtil.process_util(prev, curr)
      %{sys: 0.1, total: 0.2, user: 0.1}
  """
  @spec process_util({binary(), binary()}, {binary(), binary()}, keyword()) :: util()
  def process_util(prev, curr, opts \\ []) when is_tuple(prev) and is_tuple(curr) do
    util1 = %{total: prev |> elem(0) |> total_time(), stats: prev |> elem(1) |> stat_pid()}
    util2 = %{total: curr |> elem(0) |> total_time(), stats: curr |> elem(1) |> stat_pid()}
    calc_pid_util(util1, util2, opts[:cores] || 1, opts[:precision] || 1)
  end

  @doc """
  Get the cpu for the given os_pid and number of cores.

  Blocks the calling process for time (1) seconds to collect the before and
  after samples.
  """
  @spec get_cpu_util(integer(), keyword()) :: util()
  def get_cpu_util(pid, opts \\ []) do
    util1 = pid_util(pid)
    Process.sleep(Keyword.get(opts, :time, 1) * 1000)
    util2 = pid_util(pid)

    calc_pid_util(util1, util2, Keyword.get(opts, :cores, 1), Keyword.get(opts, :precision, 1))
  end
end
