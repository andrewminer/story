window.STORY = new Story "A Walk Through My House", ->

    # Items ############################################################################################################

    boxOfTile = @addItem "box of tiles"
    boxOfTile.description =
        "This appears to be a box of flooring tiles. The tiles appear to be a very light color of natural stone. It is
        quite heavy."
    boxOfTile.take = =>
        @log.writeln "Oof! It's too heavy."
        return false

    hose = @addItem "garden hose"
    hose.description = "It's a pretty ordinary garden hose about 20' long."

    # Locations ########################################################################################################

    car = @addLocation "Your Car"
    car.description =
        "Your car isn't anything special, but it does get you around."
    car.addVerb "drive", "start", =>
        @log.writeln("Having finished your visit, you drive back home again.")
        @endGame()

    driveway = @addLocation "Driveway"
    driveway.description =
        "The driveway is paved with concrete, and quite large: room enough for five or six cars. Your own car is the
        only one here at the moment, though. The driveway extends slightly uphill a short way to the west back to the
        street. At this part, it's recessed a little below the level of the lawn with a stone wall defining the
        boundary.\n\nFrom where you're standing, it looks like most of the property has been left wild with tall,
        scraggly pine trees swaying in a light breeze. Immediately surrounding the house is a short-cropped lawn. To the
        south are three garage doors which make up the entire side of the house. Above the doors are a few windows. The
        back yard is to the east, and the some steps lead up to the front porch to the southwest."
    driveway.addItem hose

    frontPorch = @addLocation "Front Porch"
    frontPorch.description =
        "You're standing on the front porch. It's a large wooden deck with an overhang above, and a railing all about.
        To the north, a staircase leads down a dozen steps or so to the driveway. To the south double door leads inside
        the house. It has a fancy crystal inset in the windows, so while you can see a light on inside the house, you
        can't make out any details."
    frontPorch.addItem boxOfTile

    # Configure Map ####################################################################################################

    driveway.addTransition "in", car
    driveway.addTransition "southwest", frontPorch
    frontPorch.addTransition "north", driveway

    @currentLocation = frontPorch
