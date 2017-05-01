
def some_test(node):
    journal.beginTest("This is some test")

    if node.run("uptime"):
        journal.success("Test on " + node.name + " has succeeded")
    else:
        journal.failure("Test on " + node.name + " has failed")

######################

setup()

try:
