try Dataiku.delete(project"TEST_JULIA_VARIABLES") catch end
project = Dataiku.create_project("TEST_JULIA_VARIABLES")

Dataiku.set_current_project(project)


variables = Dataiku.get_custom_variables()
@test variables["projectKey"] == project.key

Dataiku.add_local_variable("test" => 5)
@test Dataiku.get_local_variables()["test"] == 5

Dataiku.add_standard_variable("test" => 6)
@test Dataiku.get_standard_variables()["test"] == 6

@test Dataiku.get_custom_variables()["test"] == 5

Dataiku.delete(project)