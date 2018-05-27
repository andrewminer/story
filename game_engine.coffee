class GameLog

    constructor: (onChange=(->))->
        @content = ""
        @onChange = onChange

    echoInput: (text)->
        @content += "<br>&gt; " + text + "<br>"
        @onChange(this)

    writeln: (text="")->
        @content += text.replace(/\n/g, "<br>") + "<br>"
        @onChange(this)


########################################################################################################################

class Inventory

    constructor: ->
        @items = {}
        @length = 0

    add: (item)->
        if not @items[item.name]
            @items[item.name] = item
            @length += 1

    describe: (options={})->
        options.simple ?= false
        result = []

        for name, item of @items
            if options.simple
                result.push(item.name)
            else
                result.push("There is a #{item.name} here.")

        return result.join("\n")

    eachItem: (withItem=(->))->
        for name, item of @items
            withItem(item)

    has: (item)->
        return !! @items[item.name]

    remove: (itemToRemove)->
        if @items[itemToRemove.name]
            delete @items[itemToRemove.name]
            @length -= 1


########################################################################################################################

class Item

    constructor: (@name)->
        @description = "non-descript item"

    describe: ->
        return @description

    toString: ->
        return @name


########################################################################################################################

class Location

    constructor: (@name)->
        @description = "Non-descript Place"
        @destinations = {}
        @inventory = new Inventory()
        @transitions = []
        @visited = false

    addTransition: (direction, toLocation, locked=false)->
        @transitions[direction] = new Transition(direction, toLocation, locked)

    addItem: (item)->
        @inventory.add(item)
        return this

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
        @items.remove(item)
        return this

    toString: ->
        return @name


########################################################################################################################

class ParseError extends Error


########################################################################################################################

class Parser

    constructor: (@story)->
        @aliases = {}
        @directions = []
        @verbs = {}
        @fillerWords = new Set()

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
        sentence = new Sentence
        for rawWord in userInput.split(/\s\s*/)
            rawWord = @_resolveAliases(rawWord)

            if @_useAsFiller(rawWord, sentence) then continue
            if @_useAsVerb(rawWord, sentence) then continue
            if @_useAsItem(rawWord, sentence) then continue
            if @_useAsLocation(rawWord, sentence) then continue

            throw new ParseError("I'm not sure what you meant by #{rawWord}... can you re-phrase that?")

        @_normalizeSentence(sentence)
        @_validateSentence(sentence)
        return sentence

    # Private Methods ##############################################################################

    _normalizeSentence: (sentence)->
        if sentence.has(verb: 0, location: 1)
            sentence.addWord(new WordToken("go", "verb"))

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
            if rawWord is direction
                candidates.add(transition.toLocation)
            else if transition.toLocation.name.indexOf(rawWord) isnt -1
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

class Player

    constructor: (@story)->
        @inventory = new Inventory()
        @verbs = {}

    addVerb: (verb, onVerb)->
        @verbs[verb] = onVerb
        @story.parser.addVerb(verb)

    enact: (sentence)->
        onVerb = @verbs[sentence.verb]
        if onVerb
            onVerb(sentence)
        else
            throw new ParseError("I'm not sure how to #{sentence.verb}, to be honest.")

    move: (location)->
        transition = @story.currentLocation.getTransitionTo(location)
        if not transition
            throw new ParseError("You can't get to #{location.name} from here.")
        else if transition.locked
            throw new ParseError(transition.lockDescription)

        @story.arrive(location)

    take: (item)->
        localItems = @story.currentLocation.inventory
        if not item
            localItems.eachItem (item)=> @take(item)
        else if localItems.has(item)
            localItems.remove(item)
            @inventory.add(item)
            @story.log.writeln("Taken.")
        else
            throw new ParseError("You can't take #{item} because there isn't one here.")



########################################################################################################################

class Sentence

    constructor: ->
        @tokens = item: [], location: [], verb: []

    addWord: (wordToken)->
        @tokens[wordToken.type].push(wordToken)

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

    Object.defineProperties @prototype,
        "item":
            get: -> return @tokens.item[0].referant
        "location":
            get: -> return @tokens.location[0].referant
        "verb":
            get: -> return @tokens.verb[0].rawText


########################################################################################################################

class Story

    constructor: (@title)->
        @currentLocation = null
        @items = []
        @locations = []
        @log = new GameLog()
        @parser = new Parser(this)
        @player = new Player(this)

        @_configure()

    # Configuration Methods ###########3############################################################

    addItem: (name)->
        item = new Item(name)
        @items.push(item)
        return item

    addLocation: (name)->
        location = new Location(name)
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

    begin: ->
        @log.writeln(@title)
        @log.writeln()
        @arrive(@currentLocation)

    interpret: (userInput)->
        try
            @log.echoInput(userInput)
            sentence = @parser.interpret(userInput)
            @player.enact(sentence)
        catch e
            if e instanceof ParseError
                @log.writeln(e.message)
            else
                throw e

    # Private Methods ##############################################################################

    _configure: ->
        @parser.addDirections(
            "north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest", "up", "down"
        )
        @parser.addFillerWords(
            "a",
            "an",
            "around",
            "at",
            "of",
            "the",
            "to"
        )
        @parser.addAliases({
            "d": "down",
            "e": "east",
            "everything": "all",
            "g": "go"
            "i": "inventory"
            "l": "look",
            "n": "north",
            "ne": "northeast",
            "nw": "northwest",
            "s": "south",
            "se": "southeast",
            "sw": "southwest",
            "u": "up",
            "w": "west",
        })

        @player.addVerb "go", (sentence)=>
            if sentence.has(location: 1)
                @player.move(sentence.location)
            else
                throw new ParseError("I'm not sure where you want to go...")

        @player.addVerb "inventory", =>
            if @player.inventory.length is 0
                @log.writeln("You're not carrying anything.")
            else
                @log.writeln("You have:")
                @log.writeln(@player.inventory.describe(simple: true))

        @player.addVerb "look", (sentence)=>
            if sentence.has(item: 1)
                @log.writeln(sentence.item.describe(verbose: true))
            else
                @log.writeln(@currentLocation.describe(verbose: true))

        @player.addVerb "take", (sentence)=>
            if sentence.has(item: 1)
                @player.take(sentence.item)
            else if sentence.has(item: 0)
                @player.take()


########################################################################################################################

class Transition

    constructor: (@direction, @toLocation, @locked=false)->
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
