window.STORY = s = new Story("A Walk Through My House")

# Items ################################################################################################################

boxOfTile = s.addItem("box of tiles")
boxOfTile.description =
    "This appears to be a box of flooring tiles. The tiles appear to be a very light color of natural stone. It is
    quite heavy."
boxOfTile.take = ->
    s.log.writeln("Oof! It's too heavy.")
    return false

hose = s.addItem("garden hose")
hose.description = "It's a pretty ordinary garden hose about 20' long."

# Locations ############################################################################################################

driveway = s.addLocation("Driveway")
driveway.description =
    "The driveway extends slightly uphill a short way to the west back to the street. At this part, it's recessed a
    little below the level of the lawn with a stone wall defining the boundary. To the east are three garage doors which
    make up the entire side of the house. Above the doors are a few windows.  The back yard is to the east, and the
    front porch is to the south."
driveway.addItem(hose)

frontPorch = s.addLocation("Front Porch")
frontPorch.description =
    "You're standing on the front porch. It's a wooden deck with a slight overhang above, and a railing all about. A
    double door is in front of you with a fancy crystal inset in the windows. There's a light on inside the house, but
    you can't make out any details."
frontPorch.addItem(boxOfTile)

# Configure Map ########################################################################################################

driveway.addTransition("southwest", frontPorch)
frontPorch.addTransition("northeast", driveway)

s.currentLocation = frontPorch
