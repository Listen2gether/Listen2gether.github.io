import
  std/[sugar, options],
  types

proc queueFilter*(
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
      else:
        result = false
  else:
    raise newException(IOError, "Listen has no listenedAt property!")

proc updateQueue*(user: User, mirror: User): seq[Listen] =
  ## Updates the `submitQueue` for a user given a mirror user.
  result = collect():
    for listen in mirror.listenHistory:
      if queueFilter(listen, user.listenHistory[0].listenedAt, user.lastSubmissionTs):
        listen

proc updateQueue*(users: seq[User], mirror: User): seq[User] =
  ## Updates the `submitQueue` for all users in `seq[User]`, given a mirror user.
  result = collect():
    for user in users:
      var updatedUser = user
      updatedUser.submitQueue.listens = updateQueue(user, mirror)
      updatedUser
