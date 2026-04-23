local i = 1
while i < 10 do
  if i == 5 then
    i = i + 2
    goto continue
  end
  local j = i
  i = i + 1
  ::continue::
  break -- this one makes the goto invalid!!
end


local i = 1
repeat
  if i == 5 then
    i = i + 2
    goto continue
  end
  local j = i
  i = i + 1
  ::continue::
until i >= 10