try Dataiku.delete(project"TEST_JULIA_FOLDERS") catch end
project = Dataiku.create_project("TEST_JULIA_FOLDERS")

Dataiku.set_current_project(project)

