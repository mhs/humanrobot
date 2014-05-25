path = require("path")
Robot       = require("hubot/src/robot")
TextMessage = require("hubot/src/message").TextMessage

describe "Reminder", () ->
  robot = undefined
  user = undefined
  adapter = undefined

  beforeEach () ->
    runs () ->
      robot = new Robot null, "mock-adapter", false

      robot.adapter.on "connected", () ->
        process.env.HUBOT_AUTH_ADMIN = "1"
        robot.loadFile(
          path.resolve(
            path.join("node_modules/hubot/src/scripts")
          ),
          "ping.coffee"
        )

        # require("hubot/index")(robot)

        user = robot.brain.userForId "1", {
          name: "jasmine",
          room: "#jasmine"
        }

        adapter = robot.adapter

      robot.run()

  afterEach () ->
    robot.shutdown()


  it "tests run good", (done) ->
    console.log "running"
    value = 1 + 4
    expect(value).toBe 5
    done()

  it "responds when greeted", (done) ->
    adapter.on "reply", (envelope, strings) ->
      console.log "we got a reply"
      expect(strings[0]).toMatch("PONG")

      done()

    adapter.receive(new TextMessage(user, "hubot ping"))
