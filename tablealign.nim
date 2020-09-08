import sequtils, ansiparse, terminal, algorithm
import unicode except repeat
from strutils import Whitespace, tokenize, split, repeat, join

import termstyle

type
  TerminalTable = object
    parts: seq[seq[seq[AnsiData]]]

proc add(table: var TerminalTable, parts: varargs[string]) =
  table.parts.add seq[seq[AnsiData]](@[])
  for part in parts:
    table.parts[^1].add part.parseAnsi

proc pureLen(ansiSequence: seq[AnsiData]): int =
  for part in ansiSequence:
    if part.kind == String:
      result += part.str.len

proc ansiAlign(ansiSeq: seq[AnsiData], amount: int): string =
  let
    str = ansiSeq.toString()
    diff = str.len - ansiSeq.pureLen
  str.alignLeft(amount + diff)

proc `[]`*(cell: seq[AnsiData], slice: Hslice[int, int]): string =
  var
    passed = 0
    csiPassed = 0
  for part in cell:
    if result.len - csiPassed > slice.b - slice.a: break
    case part.kind:
    of String:
      if passed >= slice.a:
        result.add part.str
      else:
        if passed + part.str.len > slice.a:
          result.add part.str[slice.a - passed..^1]
          passed = slice.a
        else:
          passed += part.str.len
    of CSI:
      #if passed >= slice.a:
      let csi = "\e[" & part.parameters & part.intermediate & $part.final
      result.add csi
      csiPassed += csi.len

  if slice.b - slice.a + csiPassed + 1 < result.len:
    result.setLen slice.b - slice.a + csiPassed + 1
    result &= "\e[0m"

proc olen(s: string): int =
  var i = 0
  result = 0
  while i < s.len:
    inc result
    let L = graphemeLen(s, i)
    inc i, L

func wrapWords*(s: seq[AnsiData], maxLineWidth = 80,
               splitLongWords = true,
               seps: set[char] = Whitespace): seq[seq[AnsiData]] =
  const endElem =
    AnsiData(kind: CSI, parameters: "0", intermediate: "", final: 'm')
  var
    temp: seq[AnsiData]
    spaceLeft = maxLineWidth
    lastSep = ""
    csi: seq[AnsiData]
    passedCsi: seq[AnsiData]
  for element in s:
    case element.kind:
    of CSI:
      csi.add element
      temp.add element
    of String:
      for word, isSep in tokenize(element.str, seps):
        let wlen = olen(word)
        if isSep:
          lastSep = word
          spaceLeft = spaceLeft - wlen
        elif wlen > spaceLeft:
          if splitLongWords and wlen > maxLineWidth:
            var i = 0
            while i < word.len:
              if spaceLeft <= 0:
                spaceLeft = maxLineWidth
                result.add passedCsi & temp & endElem
                passedCsi.add csi
                reset csi
                reset temp
              dec spaceLeft
              let L = graphemeLen(word, i)
              for j in 0 ..< L: temp.add AnsiData(kind: String, str: $word[i+j])
              inc i, L
          else:
            spaceLeft = maxLineWidth - wlen
            result.add passedCsi & temp & endElem
            passedCsi.add csi
            reset csi
            reset temp
            temp.add AnsiData(kind: String, str: word)
        else:
          spaceLeft = spaceLeft - wlen
          temp.add AnsiData(kind: String, str: lastSep)
          temp.add AnsiData(kind: String, str: word)
          lastSep.setLen(0)
  result.add passedCsi & temp & endElem

proc getColumnSizes*(table: TerminalTable, maxSize: int, padding = 1): seq[int] =
  for part in table.parts:
    for i, cell in part:
      if i == result.len:
        result.add cell.pureLen
      else:
        result[i] = max(result[i], cell.pureLen)
  let totalSize = result.foldl(a + b) + padding * (result.len - 1)
  if totalSize > maxSize:
    var newSizes = newSeq[tuple[val, i: int]](result.len)
    for i, size in result:
      newSizes[i] = (val: size, i: i)
    newSizes.sort(SortOrder.Descending)
    var
      resized = 0
      newSize = totalSize
    for i in 0..<result.high:
      newSize -= newSizes[i].val * (i+1)
      newSize += newSizes[i+1].val * (i+1)
      resized += 1
      if newSize <= maxSize:
        break
    let extra = maxSize - newSize
    if extra >= 0:
      for i in 0..<resized:
        result[newSizes[i].i] = newSizes[resized].val + extra div resized
        newSize += extra div resized
    else:
      for i in 0..result.high:
        result[i] = (maxSize - result.len * padding) div result.len
    var i = 0
    while newSize < maxSize:
      result[i] += 1
      newSize += 1
      i = (i + 1) mod result.len

iterator entries*(table: TerminalTable, sizes: seq[int]): iterator(): iterator(): tuple[key: int, val: string] =
  for part in table.parts:
    var
      wrapped = newSeq[seq[seq[AnsiData]]](part.len)
      longest = 0
    for i in 0..part.high:
      wrapped[i] = part[i].wrapWords(sizes[i])
      longest = max(longest, wrapped[i].len)
    yield iterator (): iterator(): tuple[key: int, val: string] =
      for i in 0..<longest:
        yield iterator(): tuple[key: int, val: string] =
          for j, w in wrapped:
            if w.len > i:
              yield (j, w[i].ansiAlign(sizes[j]))
            else:
              yield (j, ' '.repeat sizes[j])

#proc echoTable*(table: TerminalTable, maxSize = terminalWidth(), padding = 1) =
#  var sizes = table.getColumnSizes(maxSize, padding)
#  for part in table.parts:
#    var
#      wrapped = newSeq[seq[seq[AnsiData]]](part.len)
#      longest = 0
#    for i in 0..part.high:
#      wrapped[i] = part[i].wrapWords(sizes[i])
#      longest = max(longest, wrapped[i].len)
#    for i in 0..<longest:
#      for j, w in wrapped:
#        if w.len > i:
#          stdout.write w[i].ansiAlign(sizes[j])
#          if j != wrapped.high:
#            stdout.write ' '.repeat padding
#        else:
#          stdout.write ' '.repeat sizes[j]
#          if j != wrapped.high:
#            stdout.write ' '.repeat padding
#      stdout.write '\n'
const defaultSeps = (topLeft: '+', topRight: '+', topMiddle: '+', bottomLeft: '+', bottomMiddle: '+', bottomRight: '+', center: '+', vertical: '|', horizontal: '-')

proc echoTableSeps*(table: TerminalTable, maxSize = terminalWidth(), seps = defaultSeps) =
  let
    sizes = table.getColumnSizes(maxSize - 4, padding = 3)
    separator = block:
      var separator = "+"
      for size in sizes:
        separator.add ('-'.repeat(size + 2)) & "+"
      separator & "\n"
  stdout.write separator
  for entry in table.entries(sizes):
    for row in entry():
      stdout.write "| "
      for i, cell in row():
        stdout.write cell & (if i != sizes.high: " | " else: "")
      stdout.write " |\n"
    stdout.write separator

proc echoTable*(table: TerminalTable, maxSize = terminalWidth(), padding = 1) =
  let
    sizes = table.getColumnSizes(maxSize, padding = padding)
  for entry in table.entries(sizes):
    for row in entry():
      for i, cell in row():
        stdout.write cell & (if i != sizes.high: ' '.repeat(padding) else: "")
      stdout.write "\n"

when isMainModule:
  echo "Tim " & "-".repeat(123)
  var table: TerminalTable
  #parts.add @[blue "Hello world", "this is aligned"]
  #parts.add @["Tim", red "this is also aligned"]
  #table.add "Timothy", red "Ronaldson", yellow "This is a really long message that should break the width of the terminal and cause a wrapping scenario, hopefully it works so I can test wrapping.", "Test"
  table.add "Timothy", yellow "This is a really long message that should break the width of the terminal and cause a wrapping scenario, hopefully it works so I can test wrapping.", red "This is a really long message that should break the width of the terminal and cause a wrapping scenario, hopefully it works so I can test wrapping.", "Test"
  table.add blue "Ronaldson", green "This is a shorter message", "So is this", red "Last field that now includes a message long enough for this to be truncated"
  #parts.add @["Ralph", "Bob", "So is this"]




  table.echoTable(padding = 3)
  echo ""
  table.echoTableSeps(80)
  echo ""
  table.echoTable(80)



 # var ansiText = ("Lorem ipsum dolor sit amet, " & red("|consectetur adipiscing elit|") & ", sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. " & yellow("|Duis aute irure dolor in reprehenderit|") & " in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.").parseAnsi
 # echo ansiText.wrapWords(50)
 # for i in 1..50:
 #   echo ansiText.wrapWords(i).join "\n"
