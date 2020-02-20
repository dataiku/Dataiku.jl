try Dataiku.delete(project"TEST_JULIA_FOLDERS") catch end
project = Dataiku.create_project("TEST_JULIA_FOLDERS")

Dataiku.set_current_project(project)

test_data_dir = joinpath(dirname(dirname(pathof(Dataiku))), "test", "data")

test_folder = Dataiku.create_managed_folder("test_folder")
@test Dataiku.get_settings(test_folder)["name"] == "test_folder"
@test Dataiku.upload_file(test_folder, joinpath(test_data_dir, "no_part.csv"))["size"] == 160

@test Dataiku.list_contents(test_folder)["items"] |> length == 1
@test Dataiku.get_file_content(test_folder, "/no_part.csv") |> length == 160
@test Dataiku.copy_file(test_folder, "/no_part.csv", test_folder, "/no_part2.csv")["size"] == 160

@test Dataiku.list_contents(test_folder)["items"] |> length == 2
@test Dataiku.get_file_content(test_folder, "/no_part2.csv") |> length == 160
Dataiku.delete_path(test_folder, "/no_part2.csv")

@test Dataiku.list_contents(test_folder)["items"] |> length == 1
Dataiku.clear_data(test_folder)

@test Dataiku.list_contents(test_folder)["items"] |> length == 0
Dataiku.delete(test_folder)
Dataiku.delete(project)