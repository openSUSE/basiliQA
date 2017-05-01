
except susetest.BasiliqaError as e:
    journal.writeReport()
    sys.exit(e.code)

except:
    print "Unexpected error"
    journal.info(traceback.format_exc(None))
    raise

journal.writeReport()
