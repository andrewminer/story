configureDefaults = (story)->
    player = story.player
    player.addVerb "drop", (sentence)-> player.drop(sentence)
    player.addVerb "go", (sentence)-> player.go(sentence)
    player.addVerb "inventory", (sentence)-> player.listInventory(sentence)
    player.addVerb "take", (sentence)-> player.take(sentence)

    story.addVerb "look", (sentence)-> story.look(sentence)
    story.addVerb "restart", -> story.reset()

    parser = story.parser
    parser.addDirections(
        "north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest", "up", "down", "in", "out"
    )
    parser.addFillerWords(
        "a", "all", "an", "around", "at", "everything", "my", "of", "it", "the", "to", "thing"
    )
    parser.addAliases({
        "d": "down",
        "e": "east",
        "g": "go",
        "i": "inventory",
        "into": "in",
        "l": "look",
        "n": "north",
        "ne": "northeast",
        "nw": "northwest",
        "s": "south",
        "se": "southeast",
        "sw": "southwest",
        "u": "up",
        "w": "west"
    })
    parser.addVerb("get")

########################################################################################################################

class Actor

    constructor: (story)->
        @_verbs = {}
        @story = story or this

    # Public Methods ###############################################################################

    addVerb: (verbs..., action)->
        for verb in verbs
            @_verbs[verb] = action
            @story.parser.addVerb(verb)

    can: (verb)->
        return !! @_verbs[verb]

    do: (sentence)->
        if @can(sentence.verb)
            @_verbs[sentence.verb](sentence)
            return true
        return false

    reset: ->
        @_verbs = {}


########################################################################################################################

class GameLog

    constructor: (onChange=(->))->
        @content = ""
        @onChange = onChange

    clear: ->
        @content = ""
        @onChange(this)

    echoInput: (text)->
        @content += "<br>&gt; " + text + "<br>"
        @onChange(this)

    write: (text="")->
        @content += text.replace(/\n/g, "<br>")
        @onChange(this)

    writeln: (text="")->
        @write(text + "\n")


########################################################################################################################

class Inventory

    constructor: ->
        @clear()

    # Properties ###################################################################################

    Object.defineProperties @prototype,
        items:
            get: -> return (item for name, item of @_items)
        length:
            get: -> return @_length

    # Public Methods ###############################################################################

    add: (item)->
        if not @_items[item.name]
            @_items[item.name] = item
            @_length += 1

    all: ->
        return (item for name, item of @_items)

    clear: ->
        @_items = {}
        @_length = 0

    describe: (options={})->
        options.simple ?= false
        result = []

        for name, item of @_items
            if options.simple
                result.push(item.name)
            else
                result.push("There is a #{item.name} here.")

        return result.join("\n")

    eachItem: (withItem=(->))->
        for name, item of @_items
            withItem(item)

    has: (item)->
        return !! @_items[item.name]

    remove: (itemToRemove)->
        if @_items[itemToRemove.name]
            delete @_items[itemToRemove.name]
            @_length -= 1


########################################################################################################################

class Item extends Actor

    constructor: (story, name, options={})->
        options.fixed ?= false
        super(story)

        @description = "non-descript item"
        @fixed = options.fixed
        @name = name

    # Public Methods ###############################################################################

    take: ->
        if @fixed
            @story.log.writeln("You cannot take the #{@name}.")
            return false
        else
            @story.log.writeln("Taken.")
            return true

    describe: ->
        return @description

    toString: ->
        return @name


########################################################################################################################

class Location extends Actor

    constructor: (story, name)->
        super(story)

        @description = "Non-descript Place"
        @destinations = {}
        @inventory = new Inventory()
        @name = name
        @transitions = []
        @visited = false

    # Public Methods ###############################################################################

    addTransition: (direction, toLocation, locked=false)->
        @transitions[direction] = new Transition(direction, toLocation, locked)

    addItem: (item)->
        @inventory.add(item)

    describe: (options={})->
        options.verbose ?= false
        result = [@name]

        if (not @visited) or options.verbose
            result.push("\n")
            result.push(@description)

        if @inventory.length > 0
            result.push("")
            result.push(@inventory.describe())

        return result.join("\n")

    getTransitionTo: (location)->
        for direction, transition of @transitions
            if transition.toLocation is location
                return transition
        return undefined

    removeItem: (item)->
        @inventory.remove(item)

    reset: ->
        super()
        @inventory.clear()

    toString: ->
        return @name


########################################################################################################################

class ParseError extends Error


########################################################################################################################

class Parser

    constructor: (story)->
        @story = story
        @reset()

    addAliases: (aliasMap)->
        for alias, meaning of aliasMap
            @aliases[alias] = meaning

    addDirections: (words...)->
        for word in words
            @directions.push(word)

    addFillerWords: (words...)->
        for word in words
            @fillerWords.add(word)

    addVerb: (verb)->
        @verbs[verb] = verb

    interpret: (userInput)->
        userInput = userInput.toLowerCase()
        sentence = new Sentence
        for rawWord in userInput.split(/\s\s*/)
            rawWord = @_resolveAliases(rawWord)

            if @_useAsFiller(rawWord, sentence) then continue
            if @_useAsVerb(rawWord, sentence) then continue
            if @_useAsItem(rawWord, sentence) then continue
            if @_useAsLocation(rawWord, sentence) then continue

            throw new ParseError("I'm not sure what you meant by #{rawWord}... can you re-phrase that?")

        sentence = @_normalizeSentence(sentence)
        @_validateSentence(sentence)
        return sentence

    reset: ->
        @aliases = {}
        @directions = []
        @fillerWords = new Set()
        @verbs = {}

    # Private Methods ##############################################################################

    _normalizeSentence: (sentence)->
        if sentence.has(verb: 0, location: 1)
            sentence.addWord(new WordToken("go", "verb"))
        else if sentence.has(verb: 0, item: 1)
            sentence.addWord(new WordToken("take", "verb"))
        else if sentence.verb is "get"
            if sentence.has(location: 1)
                sentence = new Sentence(new WordToken("go", "verb"), sentence.tokens.location[0])
            if sentence.has(item: 1)
                sentence = new Sentence(new WordToken("take", "verb"), sentence.tokens.item[0])

        return sentence

    _resolveAliases: (rawWord)->
        meaning = @aliases[rawWord]
        if meaning
            return @_resolveAliases(meaning)
        return rawWord

    _useAsFiller: (rawWord)->
        return @fillerWords.has(rawWord)

    _useAsItem: (rawWord, sentence)->
        candidates = {}

        considerItem = (item)->
            if item.name.indexOf(rawWord) isnt -1
                candidate = candidates[item.name] ?= {item: item; count: 0}
                candidate.count += 1

        @story.player.inventory.eachItem(considerItem)
        @story.currentLocation.inventory.eachItem(considerItem)

        candidates = (item for name, item of candidates)
        return false if candidates.length is 0

        highestCount = 0
        mostPopular = []
        for candidate in candidates
            if candidate.count is highestCount
                mostPopular.push(candidate)
            else if candidate.count > highestCount
                highestCount = candidate.count
                mostPopular = [candidate]

        if mostPopular.length > 1
            throw new ParseError(
                "I'm not sure what you meant by #{rawWord}... which did you mean: #{mostPopular.join(", ")}"
            )

        sentence.addWord(new WordToken(rawWord, "item", mostPopular[0].item))
        return true

    _useAsVerb: (rawWord, sentence)->
        if not @verbs[rawWord]
            return false

        sentence.addWord(new WordToken(rawWord, "verb"))
        return true

    _useAsLocation: (rawWord, sentence)->
        candidates = new Set()

        for directionWord in @directions
            if rawWord is directionWord
                transition = @story.currentLocation.transitions[directionWord]
                if transition
                    candidates.add(transition.toLocation)
                else
                    throw new ParseError("You can't go #{rawWord} from here.")

        for direction, transition of @story.currentLocation.transitions
            if transition.toLocation.name.toLowerCase().indexOf(rawWord) isnt -1
                candidates.add(transition.toLocation)

        if @story.currentLocation.name.indexOf(rawWord) isnt -1
            candidates.add(@story.currentLocation)

        candidates = Array.from(candidates)

        if candidates.length > 1
            throw new ParseError("I'm not sure what you meant by #{rawWord}... did you mean: #{candidates.join(", ")}")
        else if candidates.length is 0
            return false

        if candidates[0] is @story.currentLocation
            throw new ParseError("You're already there!")

        sentence.addWord(new WordToken(rawWord, "location", candidates[0]))
        return true

    _validateSentence: (sentence)->
        if sentence.has(verb: 0)
            throw new ParseError("I'm not sure what you wanted to do there.")


########################################################################################################################

class Player extends Actor

    constructor: (story)->
        super(story)

        @inventory = new Inventory()
        @onChange = (->)

    # Properties ###################################################################################

    Object.defineProperties @prototype,
        score:
            get: ->
                return @_score
            set: (value)->
                @_score = value
                @onChange(this)

    # Public Methods ###############################################################################

    drop: (sentence)->
        items = sentence.items
        if items.length is 0
            items = @inventory.all()

        for item in items
            if @inventory.has(item)
                @inventory.remove(item)
                @story.currentLocation.inventory.add(item)
                @story.log.writeln("Dropped #{item.name}.")
            else
                @story.log.writeln("You're not holding a #{item.name}.")

    go: (sentence)->
        if not sentence.location
            throw new ParseError("I'm not sure where you want to go...")

        location = sentence.location
        transition = @story.currentLocation.getTransitionTo(location)
        if not transition
            throw new ParseError("You can't get to #{location.name} from here.")

        @story.arrive(location)

    listInventory: (sentence)->
        if @inventory.length is 0
            @story.log.writeln("You're not carrying anything.")
        else
            @story.log.writeln("You have:")
            @story.log.writeln(@inventory.describe(simple: true))

    take: (sentence)->
        items = sentence.items
        localItems = @story.currentLocation.inventory

        if items.length is 0
            foundTakeableItem = true
            for item in localItems.items
                if not item.fixed
                    items.push(item)

            if not foundTakeableItem
                @story.log.writeln("There's nothing here you can take.")

        _doTake = (item)=>
            if localItems.has(item)
                if item.take()
                    localItems.remove(item)
                    @inventory.add(item)
            else
                throw new ParseError("There isn't a #{item} here.")

        if items.length > 1
            for item in items
                @story.log.write("#{item}: ")
                _doTake(item)
        else
            _doTake(items[0])

    reset: ->
        super()
        @inventory.clear()
        @score = 0


########################################################################################################################

class Sentence

    constructor: (tokens...)->
        @tokens = item: [], location: [], verb: []

        for token in tokens
            @addWord(token)

    # Properties ###################################################################################

    Object.defineProperties @prototype,
        "item":
            get: -> return @tokens.item[0].referant
        "items":
            get: -> (i.referant for i in @tokens.item)
        "location":
            get: -> return @tokens.location[0].referant
        "verb":
            get: -> return @tokens.verb[0].rawText

    # Public Methods ###############################################################################

    addWord: (wordToken)->
        tokenList = @tokens[wordToken.type]
        for existingToken in tokenList
            if existingToken.referant and existingToken.referant is wordToken.referant
                return
        tokenList.push(wordToken)

    has: (patternMap)->
        patternMap ?= {}

        for type, count of patternMap
            if @tokens[type].length isnt count
                return false

        return true

    toString: ->
        return (
            "{" +
            "items: [#{@tokens.item.join(", ")}], " +
            "locations: [#{@tokens.location.join(", ")}], " +
            "verbs: [#{@tokens.verb.join(", ")}]" +
            "}"
        )


########################################################################################################################

class Story extends Actor

    constructor: (title, onRestart=(->))->
        super()

        @log = new GameLog()
        @onChange = (->)
        @onRestart = onRestart
        @parser = new Parser(this)
        @player = new Player(this)
        @possibleScore = undefined
        @title = title

    # Properties ###################################################################################

    Object.defineProperties @prototype,
        "turns":
            get: ->
                return @_turns
            set: (value)->
                @_turns = value
                @onChange(this)

    # Configuration Methods ###########3############################################################

    addItem: (name, options={})->
        item = new Item(this, name, options)
        item.story = this
        @items.push(item)
        return item

    addLocation: (name)->
        location = new Location(this, name)
        @locations.push(location)
        if @initialLocation is null
            @initialLocation = location
        return location

    # Game Action Methods ##########################################################################

    arrive: (location)->
        @currentLocation = location
        @log.writeln(location.describe())
        @log.writeln()

        location.visited = true

    endGame: ->
        @currentLocation = null
        @log.writeln("\n\nThanks for playing! Say: \"restart\" to play again!\n\n\n")

    interpret: (userInput, options={})->
        options.silent ?= false

        try
            if not options.silent
                @log.echoInput(userInput)
                @turns += 1

            sentence = @parser.interpret(userInput)

            if @do(sentence) then return
            if @player.do(sentence) then return
            if @currentLocation and @currentLocation.do(sentence) then return
            for item in @currentLocation.inventory.items
                if item.do(sentence) then return

            throw new ParseError("To be honest, I'm not sure how to #{sentence.verb} anything around here.")
        catch e
            if e instanceof ParseError
                @log.writeln(e.message)
            else
                throw e

    look: (sentence)->
        if sentence.has(item: 1)
            @story.log.writeln(sentence.item.describe(verbose: true))
        else
            @story.log.writeln(@story.currentLocation.describe(verbose: true))

    reset: ->
        super()

        @currentLocation = null
        @items = []
        @locations = []
        @turns = 0

        @log.clear()
        @parser.reset()
        @player.reset()

        configureDefaults(this)
        @onRestart()

        @log.writeln(@title)
        @log.writeln()
        @arrive(@currentLocation)


########################################################################################################################

class Transition

    constructor: (@direction, @toLocation)->
        # do nothing

    toString: ->
        return "#{@direction} to #{@toLocation.name}"


########################################################################################################################

class WordToken

    constructor: (@rawText, @type, @referant=undefined)->
        # do nothing

    toString: ->
        return "{rawText: #{@rawText}, type: #{@type}, referant: #{@referant}}"


########################################################################################################################

window.Story = Story
