
def setup():
    global @@NODESLIST@@, journal

    config = susetest.Config("@@TYPE@@-@@PROGRAM@@")
    journal = config.journal

