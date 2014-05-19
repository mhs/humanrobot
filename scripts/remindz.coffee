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
#   hubot remind me at/on <time> to <action> repeat <repeat>
#
# Author:
#   ross-hunter

moment = require 'moment'
# Util = require 'util'


class Reminders
  constructor: (@robot) ->
    @cache = []
    @current_timeout = null

    @robot.brain.on 'loaded', =>
      if @robot.brain.data.reminders
        @cache = @robot.brain.data.reminders
        @queue()

  add: (reminder) ->
    # @robot.reply reminder.msg_envelope, "Add"
    # @robot.reply reminder.msg_envelope, "#{Util.inspect(reminder)}"
    @cache.push reminder
    @cache.sort (a, b) -> a.time - b.time
    @robot.brain.data.reminders = @cache
    @queue()

  removeFirst: ->
    reminder = @cache.shift()
    # @robot.reply reminder.msg_envelope, "Remove"
    # @robot.reply reminder.msg_envelope, "#{Util.inspect(reminder)}"
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
          @robot.reply reminder.msg_envelope, 'you asked me to remind you to ' + reminder.action + ' on ' + reminder.dueDate() + ' and repeat ' + reminder.repeat
          if reminder.repeat != "none"
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
  constructor: (@msg_envelope, @time, @action, @repeat) ->

  dueDate: ->
    @time.toLocaleString()

  nextRepeat: ->
    if @repeat == "daily"
      @time = moment(@time).add('days', 1).toDate()
    else if @repeat == "weekly"
      @time = moment(@time).add('weeks', 1).toDate()
    else if @repeat == "minutely"
      @time = moment(@time).add('minutes', 1).toDate()


module.exports = (robot) ->

  reminders = new Reminders robot

  robot.respond /remind me (at|on) (.*) to (.*) repeat (none|daily|weekly|minutely)/i, (msg) ->
    action = msg.match[3]
    repeat = msg.match[4]
    time = new Date(msg.match[2])
    # if you don't give a year you will get 2001. This defaults year to this one
    time = moment(time).year(moment().year()).toDate() if moment(time).year() < moment().year()
    reminder = new Reminder msg.envelope, time, action, repeat
    reminders.add reminder
    msg.send 'I\'ll remind you to ' + action + ' on ' + reminder.dueDate() + ' and repeat ' + repeat
