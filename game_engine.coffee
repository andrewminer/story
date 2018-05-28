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

class Item

    constructor: (@name, options={})->
        options.fixed ?= false

        @description = "non-descript item"
        @fixed = options.fixed
        @story = null

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

class Location

    constructor: (@name)->
        @description = "Non-descript Place"
        @destinations = {}
        @inventory = new Inventory()
        @transitions = []
        @visited = false

    # Public Methods ###############################################################################

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

        console.log("@inventory.length: #{@inventory.length}")
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
        @restart()

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

    restart: ->
        @aliases = {}
        @directions = []
        @fillerWords = new Set()
        @verbs = {}

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
        @onChange = (->)
        @restart()

    # Properties ###################################################################################

    Object.defineProperties @prototype,
        score:
            get: ->
                return @_score
            set: (value)->
                @_score = value
                @onChange(this)

    # Public Methods ###############################################################################

    addVerb: (verb, onVerb)->
        @verbs[verb] = onVerb
        @story.parser.addVerb(verb)

    drop: (items...)->
        if items.length is 0
            items = @inventory.all()

        for item in items
            if @inventory.has(item)
                @inventory.remove(item)
                @story.currentLocation.inventory.add(item)
                @story.log.writeln("Dropped #{item.name}.")
            else
                @story.log.writeln("You're not holding a #{item.name}.")

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

    restart: ->
        @verbs = {}
        @inventory.clear()
        @score = 0
        @_configureDefaultVerbs()

    take: (item)->
        localItems = @story.currentLocation.inventory
        if not item
            foundTakeableItem = false
            localItems.eachItem (item)=>
                if not item.fixed
                    @story.log.write("#{item}: ")
                    foundTakeableItem = true
                    @take(item)

            if not foundTakeableItem then @story.log.writeln("There's nothing here you can take.")
        else if localItems.has(item)
            if item.take()
                localItems.remove(item)
                @inventory.add(item)
        else
            throw new ParseError("There isn't a #{item} here.")

    # Private Methods ##############################################################################

    _configureDefaultVerbs: ->
        @addVerb "drop", (sentence)=>
            if sentence.has(item: 0)
                @drop()
            else
                for itemToken in sentence.tokens.item
                    @drop(itemToken.referant)

        @addVerb "go", (sentence)=>
            if sentence.has(location: 1)
                @move(sentence.location)
            else
                throw new ParseError("I'm not sure where you want to go...")

        @addVerb "inventory", =>
            if @inventory.length is 0
                @story.log.writeln("You're not carrying anything.")
            else
                @story.log.writeln("You have:")
                @story.log.writeln(@inventory.describe(simple: true))

        @addVerb "look", (sentence)=>
            if sentence.has(item: 1)
                @story.log.writeln(sentence.item.describe(verbose: true))
            else
                @story.log.writeln(@story.currentLocation.describe(verbose: true))

        @addVerb "restart", =>
            @story.restart()

        @addVerb "take", (sentence)=>
            if sentence.has(item: 0)
                @take()
            else
                for item in sentence.items
                    @take(item)


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
        "items":
            get: -> (i.referant for i in @tokens.item)
        "location":
            get: -> return @tokens.location[0].referant
        "verb":
            get: -> return @tokens.verb[0].rawText


########################################################################################################################

class Story

    constructor: (@title, @onRestart=(->))->
        @log = new GameLog()
        @parser = new Parser(this)
        @player = new Player(this)

        @onChange = (->)

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
        item = new Item(name, options)
        item.story = this
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

    interpret: (userInput)->
        try
            @log.echoInput(userInput)
            @turns += 1
            sentence = @parser.interpret(userInput)
            @player.enact(sentence)
        catch e
            if e instanceof ParseError
                @log.writeln(e.message)
            else
                throw e

    # Private Methods ##############################################################################

    restart: ->
        @currentLocation = null
        @items = []
        @locations = []
        @turns = 0

        @log.clear()
        @parser.restart()
        @player.restart()

        @parser.addDirections(
            "north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest", "up", "down"
        )
        @parser.addFillerWords(
            "a", "all", "an", "around", "at", "everything", "of", "the", "to"
        )
        @parser.addAliases({
            "d": "down", "e": "east", "g": "go", "i": "inventory", "l": "look", "n": "north", "ne": "northeast",
            "nw": "northwest", "s": "south", "se": "southeast", "sw": "southwest", "u": "up", "w": "west",
        })

        @onRestart()
        @log.writeln(@title)
        @log.writeln()
        @arrive(@currentLocation)


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
