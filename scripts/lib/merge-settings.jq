# Merge settings.base.json (.[0]) with a machine-local override (.[1]).
# Objects merge recursively, arrays concatenate without duplicates, and for
# everything else the local value wins. Works on jq 1.6.
def uniq_stable: reduce .[] as $x ([]; if any(.[]; . == $x) then . else . + [$x] end);

def dmerge($a; $b):
  if ($a | type) == "object" and ($b | type) == "object" then
    reduce ((($a | keys_unsorted) + ($b | keys_unsorted)) | uniq_stable | .[]) as $k
      ({};
        .[$k] = (
          if ($a | has($k)) and ($b | has($k)) then dmerge($a[$k]; $b[$k])
          elif ($b | has($k)) then $b[$k]
          else $a[$k]
          end))
  elif ($a | type) == "array" and ($b | type) == "array" then
    ($a + $b) | uniq_stable
  else $b
  end;

dmerge(.[0]; .[1])
