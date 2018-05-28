# Constants ############################################################################################################

RETURN_KEY = 13


# Global Data ##########################################################################################################

$(document).ready ->
    # configure player input box
    $input = $("input.entry")
    $input.on "keydown", ->
        if event.which isnt RETURN_KEY then return
        STORY.interpret($input.val())
        $input.val("")

    # configure the story log display
    $log = $(".log")
    $logText = $("p.log-text")
    STORY.log.onChange = (log)->
        $logText.html(log.content)
        $log.scrollTop($log[0].scrollHeight)

    # configure the score display
    $score = $(".score")
    STORY.player.onChange = (player)->
        $score.text("score: #{player.score}")
    STORY.player.onChange(STORY.player)

    # configure the turns display
    $turns = $(".turns")
    STORY.onChange = (story)->
        $turns.text("turns: #{story.turns}")
    STORY.onChange(STORY)

    # start the story
    STORY.restart()
    $input.focus()
