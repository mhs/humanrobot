# Description:
#   Alarm your people
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   hubot remind me at/on <time> to <action> repeat <repeat> (weekly, daily, none)
#   hubot stop all reminders
#
# Author:
#   ross-hunter

moment = require 'moment'
Util = require 'util'

class Reminders
  constructor: (@robot) ->
    @cache = []
    @current_timeout = null

    @robot.brain.on 'loaded', =>
      if @robot.brain.data.reminders
        @cache = @robot.brain.data.reminders
        @queue()

  add: (reminder) ->
    @cache.push reminder
    @cache.sort (a, b) -> a.time - b.time
    @robot.brain.data.reminders = @cache
    @queue()

  removeFirst: ->
    reminder = @cache.shift()
    @robot.brain.data.reminders = @cache
    reminder

  queue: ->
    clearTimeout @current_timeout if @current_timeout
    if @cache.length > 0
      now = new Date().getTime()
      @removeFirst() until @cache.length is 0 or @cache[0].time > now
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

        extendTimeout @cache[0].time - now, trigger

class Reminder
  constructor: (params) ->
    @room = params.room
    @user = params.user
    @subject = params.subject
    @time = params.time
    @action = params.action
    @repeat = params.repeat

  send: (robot) ->
    if @room
      robot.send({room: @room}, @text())
    else if @user
      robot.send({user: @user}, @text())

  dueDate: ->
    @time.toLocaleString()

  nextRepeat: ->
    if @repeat == "daily"
      if moment(@time).weekday() == 5 # Friday
        days = 3 # Monday
      else
        days = 1
      @time = moment(@time).add('days', days).toDate()
    else if @repeat == "weekly"
      @time = moment(@time).add('weeks', 1).toDate()
    else if @repeat == "minutely"
      @time = moment(@time).add('minutes', 1).toDate()

  text: ->
    "#{@subject} it's time to #{@action}"


module.exports = (robot) ->

  reminders = new Reminders robot

  robot.respond /remind (.*) (at|on) (.*) to (.*)/i, (msg) ->

    if msg.match[1] == "me"
      subject = "@#{msg.envelope.user.name}"
    else
      subject = "@#{msg.match[1]}"

    # if you don't give a year, default to current year
    if moment(new Date(msg.match[3])).year() < moment().year()
      time = moment(new Date(msg.match[3])).year(moment().year()).toDate()
    else
      time = new Date(msg.match[3])

    parsed_action = msg.match[4].match /(.*) and repeat (.*)/i

    if parsed_action
      repeat = parsed_action[2]
      action = parsed_action[1]
    else
      action = msg.match[4]

    room = msg.envelope.room
    user = msg.envelope.user

    reminder = new Reminder {room: room, user: user, subject: subject, time: time, action: action, repeat: repeat}
    reminders.add reminder

    msg.send "I\'ll remind #{subject} to #{action} on #{reminder.dueDate()} and repeat #{repeat}"


  robot.respond /(stop|clear|kill|remove)( all)? reminders/i, (msg) ->
    reminders.cache = []

    msg.send "OK, I'll stop"


  robot.respond /(stop|clear|kill|remove) reminder (\d)/i, (msg) ->
    msg.send "OK, I will remove [#{reminders.cache[parseInt(msg.match[2]) - 1].text()}]"
    reminders.cache.splice(parseInt(msg.match[2]) - 1, 1)


  robot.respond /(list|show)( me)?( all)? reminders/i, (msg) ->
    response = "OK, here are the reminders \n"
    for reminder in reminders.cache
      response += "#{reminder.text()} #{reminder.dueDate()} #{reminder.repeat} \n"

    msg.send response
