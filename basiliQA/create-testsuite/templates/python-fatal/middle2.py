
def some_test(node):
    journal.beginTest("This is some test")

    if not node.run("uptime"):
        journal.failure("Test on " + node.name + " has failed")
        raise susetest.BasiliqaError(1)

    journal.success("Test on " + node.name + " has succeeded")

######################

setup()

try:
