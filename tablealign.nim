import sequtils, ansiparse, terminal, math, algorithm
import unicode except repeat
from strutils import Whitespace, tokenize, split, repeat, join

import termstyle

type
  TerminalTable = object
    padding: int
    parts: seq[seq[seq[AnsiData]]]

#proc newTerminalTable(): TerminalTable =
#  new result

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

proc hasSpaces(cell: seq[AnsiData]): int =
  (if cell.toString(stripAnsi = true).contains(' '): 1 else: 0)


proc `[]`(cell: seq[AnsiData], slice: Hslice[int, int]): string =
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
               seps: set[char] = Whitespace): seq[string] =
  var temp: string
  var spaceLeft = maxLineWidth
  var lastSep = ""
  var
    csi: string
    passedCsi: string
  for element in s:
    case element.kind:
    of CSI:
      csi.add "\e[" & element.parameters & element.intermediate & $element.final
      temp.add "\e[" & element.parameters & element.intermediate & $element.final
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
                result.add passedCsi & temp & "\e[0m"
                passedCsi.add csi
                reset csi
                reset temp
              dec spaceLeft
              let L = graphemeLen(word, i)
              for j in 0 ..< L: temp.add $word[i+j]
              inc i, L
          else:
            spaceLeft = maxLineWidth - wlen
            result.add passedCsi & temp & "\e[0m"
            passedCsi.add csi
            reset csi
            reset temp
            temp.add(word)
        else:
          spaceLeft = spaceLeft - wlen
          temp.add(lastSep)
          temp.add(word)
          lastSep.setLen(0)
  result.add passedCsi & temp & "\e[0m"

template activePadding(): int =
  if i != part.high: table.padding else: 0

proc getColumnSizes(table: TerminalTable, maxSize = terminalWidth()): seq[int] =
  for part in table.parts:
    for i, cell in part:
      if i == result.len:
        result.add cell.pureLen
      else:
        result[i] = max(result[i], cell.pureLen)
  let totalSize = result.foldl(a + b) + table.padding * (result.len - 1)
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
    else:
      for i in 0..result.high:
        result[i] = (maxSize - result.len * table.padding) div result.len

proc echoTable(table: TerminalTable) =
  var sizes = table.getColumnSizes
  for part in table.parts:
    var
      wrapped = newSeq[seq[string]](part.len)
      longest = 0
    for i in 0..part.high:
      wrapped[i] = part[i].wrapWords(sizes[i])
      longest = max(longest, wrapped[i].len)
    for i in 0..<longest:
      for j, w in wrapped:
        if w.len > i:
          stdout.write w[i].parseAnsi.ansiAlign(sizes[j])
          if j != wrapped.high:
            stdout.write ' '.repeat table.padding
        else:
          stdout.write ' '.repeat sizes[j]
          if j != wrapped.high:
            stdout.write ' '.repeat table.padding
      stdout.write '\n'

when isMainModule:
  echo "Tim " & "-".repeat(123)
  var table = TerminalTable(padding: 3)
  #parts.add @[blue "Hello world", "this is aligned"]
  #parts.add @["Tim", red "this is also aligned"]
  #table.add "Timothy", red "Ronaldson", yellow "This is a really long message that should break the width of the terminal and cause a wrapping scenario, hopefully it works so I can test wrapping.", "Test"
  table.add "Timothy", yellow "This is a really long message that should break the width of the terminal and cause a wrapping scenario, hopefully it works so I can test wrapping.", red "This is a really long message that should break the width of the terminal and cause a wrapping scenario, hopefully it works so I can test wrapping.", "Test"
  table.add blue "Ronaldson", green "This is a shorter message", "So is this", red "Last field that now includes a message long enough for this to be truncated"
  #parts.add @["Ralph", "Bob", "So is this"]




  table.echoTable()
 # var ansiText = ("Lorem ipsum dolor sit amet, " & red("|consectetur adipiscing elit|") & ", sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. " & yellow("|Duis aute irure dolor in reprehenderit|") & " in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.").parseAnsi
 # echo ansiText.wrapWords(50)
 # for i in 1..50:
 #   echo ansiText.wrapWords(i).join "\n"
