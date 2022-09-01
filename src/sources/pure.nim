import
  std/[sugar, options],
  types

proc queueFilter(
  listen: Listen,
  lastUpdateTs: int,
  lastSubmissionTs: Option[int]): bool =
  ## Returns true when a Listen is either newer than `lastUpdateTs` or `lastSubmissionTs`.
  if listen.listenedAt.isSome():
    let listenedAt = get(listen.listenedAt)
    if listenedAt > lastUpdateTs:
      result = true
    if lastSubmissionTs.isSome():
      if listenedAt > get(lastSubmissionTs):
        result = true

proc updateQueue*(users: seq[User], mirror: User): seq[User] =
  ## Updates the `submitQueue` for all users in `seq[User]`, given a mirror user.
  for user in users:
    var updatedUser = user
    let queue = collect(newSeq):
      for listen in mirror.listenHistory:
        if queueFilter(listen, updatedUser.lastUpdateTs, updatedUser.lastSubmissionTs):
          listen
    updatedUser.submitQueue.listens = queue
    result.add updatedUser
