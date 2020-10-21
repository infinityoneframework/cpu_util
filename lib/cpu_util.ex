defmodule CpuUtil do
  @moduledoc """
  CPU utility functions.

  Functions to read and calculate CPU utilization for a given process.

  NOTE: Only *nix systems supported.
  """

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
          total: integer(),
          stats: proc_pid_stat()
        }

  # list of fields returned when /proc/<PID>/stat is read.
  @proc_pid_stat_fields ~w[
    pid tcomm state ppid pgrp sid tty_nr tty_pgrp flags  min_flt
    cmin_flt maj_flt cmaj_flt utime  stime cutime cstime
  ]a

  @doc """
  Get the current OS PID
  """
  @spec getpid() :: integer()
  def getpid, do: List.to_integer(:os.getpid())

  @doc """
  Get the number of CPU Cores.
  """
  @spec num_cores() :: {:ok, integer()} | :error
  def num_cores do
    with topology <- :erlang.system_info(:cpu_topology),
         processors when is_list(processors) <- topology[:processor] do
      {:ok, length(processors)}
    else
      _ -> :error
    end
  end

  @doc """
  Read the CPU's average load.
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
  * Pareses the first line ('cpu')
  * Converts the numbers (string) to integers
  """
  @spec stat() :: list() | {:error, any()}
  def stat do
    with {:ok, file} <- File.read("/proc/stat"), do: stat(file)
  end

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
  """
  @spec stat_total_time(list()) :: integer()
  def stat_total_time([_label | list]), do: Enum.sum(list)

  @doc """
  Get the total_time.

  Return the total time (from `/proc/stat`) as an integer.
  """
  @spec total_time() :: integer()
  def total_time do
    with [_ | _] = list <- stat(), do: stat_total_time(list)
  end

  @doc """
  Get the current OS <PID> stat.

  * Read `/proc/<PID>/stat` (single line of space separated fields)
  * Parse the fields and convert and numbers (string) to integers

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
  """
  @spec stat_pid(integer()) :: proc_pid_stat() | {:error, any()}
  def stat_pid(pid) when is_integer(pid) do
    with {:ok, file} <- File.read("/proc/#{pid}/stat"), do: stat_pid(file)
  end

  @spec stat_pid(binary()) :: proc_pid_stat() | {:error, any()}
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
  """
  @spec pid_util(integer) :: util_stat()
  def pid_util(pid),
    do: %{
      total: total_time(),
      stats: stat_pid(pid)
    }

  @doc """
  Calculate CPU utilization give 2 readings.

  ## Algorithm

  user_util = 100 * (utime_after - utime_before) / (time_total_after - time_total_before);
  sys_util = 100 * (stime_after - stime_before) / (time_total_after - time_total_before);

  ## Usage

      iex> pid = CpuUtil.os_pid()
      iex> cores = CpuUtil.num_cores()
      iex> u1 = CpuUtil.pid_util(pid)
      iex> Process.sleep(1000)
      iex> u2 = CpuUtil.pid_util(pid)
      iex> CpuUtil.calc_pid_util(u1, u2, cores)
      %{
         user: 2.0,
         sys: 0.5,
         total: 2.5
      }

  ## References

  * https://stackoverflow.com/questions/1420426/how-to-calculate-the-cpu-usage-of-a-process-by-pid-in-linux-from-c/1424556
  """
  def calc_pid_util(prev, curr, cores \\ 1, precision \\ 1) do
    try do
      t_diff = curr.total - prev.total

      user_util = 100 * (curr.stats.utime - prev.stats.utime) / t_diff * cores
      sys_util = 100 * (curr.stats.stime - prev.stats.stime) / t_diff * cores

      %{
        user: Float.round(user_util, precision),
        sys: Float.round(sys_util, precision),
        total: Float.round(user_util + sys_util, precision)
      }
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Get the cup_util for the given os_pid and number of cores.

  Blocks the calling process for time (1) seconds to collect the before and
  after samples.
  """
  def get_cpu_util(pid, cores \\ 1, time \\ 1) do
    util1 = pid_util(pid)
    Process.sleep(time * 1000)
    util2 = pid_util(pid)

    calc_pid_util(util1, util2, cores)
  end
end
