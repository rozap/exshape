# defmodule ProfileTest do
#   use ExUnit.Case

#   @moduletag timeout: 120_000
#   test "can read a thing" do
#     [{_layer_name, _prj, stream}] = Exshape.from_zip(
#       "#{__DIR__}/fixtures/2015_Street_Tree_Census_-_Tree_Data.zip"
#     )


#     then = :erlang.system_time(:micro_seconds)
#     Enum.take(stream, 30000)
#     now = :erlang.system_time(:micro_seconds)
#     IO.puts "It took #{now - then} micro seconds"

#     # :fprof.trace([:start, {:procs, self}])
#     # Enum.take(stream, 2000)
#     # :fprof.trace([:stop])
#     # :fprof.profile
#     # :fprof.analyse({:dest, 'outfile.analysis'})



#   end
# end
