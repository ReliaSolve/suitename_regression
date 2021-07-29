import re, sys


r=re.compile("\d+c\d+")
r2=re.compile('.(.*)\.(\d+)$')
input=sys.stdin
#input=open("foo.txt")


def main():
  pure=True
  lines = input.readlines()
  i = 0
  while i < len(lines):
    line = lines[i].rstrip('\n')
    match = r.match(line)
    if match:
      m1 = r2.match(lines[i+1])
      m2 = r2.match(lines[i+3])
      rest1, a = m1.group(1, 2)
      rest2, b = m2.group(1, 2)
      if abs(int(a) - int(b)) <= 1 and rest1[1:] == rest2[1:]:
        i += 4  # skip this group, it's a low order bit difference
        continue
    print(line)
    pure = False
    i += 1

  if pure: 
    exit(0)
  else:
    exit(1)


main()
