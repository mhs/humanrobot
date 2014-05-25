# Description:
#   Alarm your people
#
# Dependencies:
#   moment

# Configuration:
#   None
#
# Commands:
#   hubot remind <user> at|on <time> to <action> repeat <repeat> (weekly, daily, hourly)
#   hubot remind <user> in <time> to <action> repeat <repeat> (weekly, daily, hourly)
#   hubot stop|clear|kill|remove all reminders
#   hubot stop|clear|kill|remove reminder <index>
#
# Author:
#   ross-hunter, whitman

moment = require 'moment'

class Reminders
  constructor: (@robot) ->
    @cache = []
    @current_timeout = null

    @robot.brain.on 'loaded', =>
      @robot.brain.data.reminders ||= []
      for reminder in @robot.brain.data.reminders
        @cache.push new Reminder reminder

      @queue()

  add: (reminder) ->
    @cache.push reminder
    @cache.sort (a, b) -> a.time() - b.time()
    @robot.brain.data.reminders = @cache
    @queue()

  removeFirst: ->
    reminder = @cache.shift()
    @robot.brain.data.reminders = @cache
    reminder

  queue: ->
    @robot.brain.emit('save', @robot.brain.data.reminders)
    clearTimeout @current_timeout if @current_timeout
    if @cache.length > 0
      trigger = =>
        reminder = @removeFirst()
        reminder.send(@robot)
        if reminder.repeat
          reminder.nextRepeat()
          @add reminder
        else
          @queue()
      # setTimeout uses a 32-bit INT
      extendTimeout = (timeout, callback) ->
        if timeout > 0x7FFFFFFF
          @current_timeout = setTimeout ->
            extendTimeout (timeout - 0x7FFFFFFF), callback
          , 0x7FFFFFFF
        else
          @current_timeout = setTimeout callback, timeout

      waitFor = @cache[0].time() - new Date().getTime()
      if waitFor > 0
        extendTimeout waitFor, trigger
      else
        trigger()

class Reminder
  constructor: (params) ->
    @room = params.room
    @user = params.user
    @subject = params.subject
    @date = params.date
    @action = params.action
    @repeat = params.repeat

  send: (robot) ->
    if @room
      robot.send({room: @room}, @text())
    else if @user
      robot.send({user: @user}, @text())

  time:->
    new Date(@date).getTime()

  text: ->
    "#{@subject} it's time to #{@action}. Repeat #{@repeat}"

  nextRepeat: ->
    if @repeat == "daily"
      if moment(@date).weekday() == 5 # Friday
        days = 3 # Monday
      else
        days = 1
      next_date = moment(@date).add('days', days)
    else if @repeat == "weekly"
      next_date = moment(@date).add('weeks', 1)
    else if @repeat == "hourly"
      next_date = moment(@date).add('hours', 1)
    else if @repeat == "minutely"
      next_date = moment(@date).add('minutes', 1)
    else
      return

    @date = next_date.toDate()
    @nextRepeat() unless next_date.isAfter()


module.exports = (robot) ->

  reminders = new Reminders robot

  robot.respond /remind (.*) (at|on) (.*)( to | that )(.*)/i, (msg) ->

    if msg.match[1] == "me"
      subject = "@#{msg.envelope.user.name}"
    else
      subject = "@#{msg.match[1]}"

    # if you don't give a year, default to current year
    if moment(new Date(msg.match[3])).year() < moment().year()
      date = moment(new Date(msg.match[3])).year(moment().year()).toDate()
    else
      date = new Date(msg.match[3])

    return msg.send "Hey, that's not a real date!" unless _.isFinite(date.getTime())

    parsed_action = msg.match[5].match /(.*)( and repeat| repeat )(.*)/i
    if parsed_action
      repeat = parsed_action[3]
      action = parsed_action[1]
    else
      action = msg.match[5]

    room = msg.envelope.room
    user = msg.envelope.user

    reminder = new Reminder {room: room, user: user, subject: subject, date: date, action: action, repeat: repeat}
    reminders.add reminder

    msg.send "I\'ll remind #{subject} to #{action} on #{reminder.date} and repeat #{@repeat}"


  robot.respond /remind (.*) in (\d+) (\w+)( and )?(\d+)?( )?(\w+)?( to | that )(.*)/i, (msg) ->

    if msg.match[1] == "me"
      subject = "@#{msg.envelope.user.name}"
    else
      subject = "@#{msg.match[1]}"

    parsed_action = msg.match[9].match /(.*)( and repeat| repeat )(.*)/i
    if parsed_action
      repeat = parsed_action[3]
      action = parsed_action[1]
    else
      action = msg.match[9]

    tmpDate = moment().add(msg.match[3], msg.match[2])
    tmpDate = tmpDate.add(msg.match[7], msg.match[5]) if msg.match[5] && msg.match[7]

    room = msg.envelope.room
    user = msg.envelope.user
    date = tmpDate.toDate()

    reminder = new Reminder {room: room, user: user, subject: subject, date: date, action: action, repeat: repeat}
    reminders.add reminder

    msg.send "I\'ll remind #{subject} to #{action} on #{reminder.date} and repeat #{reminder.repeat}"


  robot.respond /(stop|clear|kill|remove)( all)? reminders/i, (msg) ->
    reminders.cache = []
    robot.brain.data.reminders = []
    robot.brain.emit('save', robot.brain.data.reminders)

    msg.send "OK, I'll stop reminding y'all"


  robot.respond /(stop|clear|kill|remove) reminder (\d)/i, (msg) ->
    msg.send "OK, I will remove [#{reminders.cache[parseInt(msg.match[2]) - 1].text()}]"

    reminders.cache.splice(parseInt(msg.match[2]) - 1, 1)
    robot.brain.data.reminders = reminders.cache
    robot.brain.emit('save', robot.brain.data.reminders)


  robot.respond /(list|show)( me)?( all)? reminders/i, (msg) ->
    response = "OK, here are the reminders \n"
    for reminder in reminders.cache
      response += "#{reminder.text()} #{reminder.date} #{reminder.repeat} \n"

    msg.send response
