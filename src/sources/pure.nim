import
  std/[sugar, options],
  types

proc queueFilter(
  listen: Listen,
  latestListenTs, lastSubmissionTs: Option[int]): bool =
  ## Returns true when a Listen is either newer than `latestListenTs` or `lastSubmissionTs`.
  if listen.listenedAt.isSome():
    let listenedAt = get(listen.listenedAt)
    if latestListenTs.isSome():
      if listenedAt > get(latestListenTs):
        result = true
    if lastSubmissionTs.isSome():
      if listenedAt > get(lastSubmissionTs):
        result = true

proc updateQueue*(users: seq[User], mirror: User): seq[User] =
  ## Updates the `submitQueue` for all users in `seq[User]`, given a mirror user.
  for user in users:
    var updatedUser = user
    updatedUser.submitQueue.listens = collect(newSeq):
      for listen in mirror.listenHistory:
        if queueFilter(listen, updatedUser.listenHistory[0].listenedAt, updatedUser.lastSubmissionTs):
          listen
    result.add updatedUser
