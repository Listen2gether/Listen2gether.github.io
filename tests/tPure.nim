import std/[unittest, options]
import ../src/types
import ../src/sources/pure

suite "Queue Filter":

  test "Listen newer than latestListenTs with none lastSubmissionTs":
    let
      listen = newListen(cstring "track", cstring "artist", listenedAt = some 1)
      latestListenTs = some 0
      lastSubmissionTs = none int
    check queueFilter(listen, latestListenTs, lastSubmissionTs)

  test "Listen newer than latestListenTs but not lastSubmissionTs":
    let
      listen = newListen(cstring "track", cstring "artist", listenedAt = some 1)
      latestListenTs = some 0
      lastSubmissionTs = some 1
    check queueFilter(listen, latestListenTs, lastSubmissionTs) == false

  test "Listen with no listenedAt property":
    let
      listen = newListen(cstring "track", cstring "artist")
      latestListenTs = some 0
      lastSubmissionTs = some 0
    expect IOError:
      discard queueFilter(listen, latestListenTs, lastSubmissionTs)
