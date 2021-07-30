import re, sys


r=re.compile("\d+c\d+")
r2=re.compile('.(.*)S==\d\.(\d+)(.*)$')
r3=re.compile('.(.*)D==\d\.(\d+)(.*)$')
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
      if m1 is not None and m2 is not None:
        before1, a, after1 = m1.group(1, 2, 3)
        before2, b, after2 = m2.group(1, 2, 3)
        if abs(int(a) - int(b)) <= 1 \
            and before1[1:] == before2[1:] \
            and after1[1:] == after2[1:]:
          i += 4  # skip this group, it's a low order bit difference
          continue
      m1 = r3.match(lines[i+1])
      m2 = r3.match(lines[i+3])
      if m1 is not None and m2 is not None:
        before1, a, after1 = m1.group(1, 2, 3)
        before2, b, after2 = m2.group(1, 2, 3)
        if abs(int(a) - int(b)) <= 1 \
            and before1[1:] == before2[1:] \
            and after1[1:] == after2[1:]:
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
