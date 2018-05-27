# Constants ############################################################################################################

RETURN_KEY = 13


# Global Data ##########################################################################################################

$(document).ready ->
    $input = $("input.entry")
    $input.on "keydown", ->
        if event.which isnt RETURN_KEY then return
        STORY.interpret($input.val())
        $input.val("")

    $log = $(".log")
    $logText = $("p.log-text")

    STORY.log.onChange = (log)->
        $logText.html(log.content)
        $log.scrollTop($log[0].scrollHeight)

    STORY.begin()
    $input.focus()
