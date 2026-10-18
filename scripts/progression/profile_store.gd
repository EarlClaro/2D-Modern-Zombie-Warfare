class_name ProfileStore
extends RefCounted
## Reads and writes the player's profile file (docs/specs/progression.md). Every function takes a path so tests and
## tools never touch the real file. Saving writes a temporary file and then swaps it in, after keeping the last good file
## as `<name>.bak`; loading falls back to that backup, sets a damaged file aside instead of deleting it, and keeps a
## file from a newer game read-only.

const PATH: String = "user://profile.json"
const MAX_SEED: int = 2147483646


enum Status {
	NEW,  ## no file: a fresh profile
	OK,  ## the file was read as it is
	MIGRATED,  ## an older file, upgraded (the old one was copied to `<name>.v<N>.bak`)
	RECOVERED,  ## the file was damaged or missing and the backup was used
	DAMAGED,  ## the file and its backup were unusable: a fresh profile, the old file kept as `<name>.corrupt-<time>.json`
	FUTURE,  ## written by a newer game: loaded read-only, never overwritten
}


class LoadResult:
	extends RefCounted
	var profile: PlayerProfile
	var status: int = Status.NEW
	## Where a damaged file was moved to ("" if nothing was).
	var kept_as: String = ""
	## Things sanitize() had to drop or repair (content that no longer exists, an illegal deck).
	var repaired: int = 0


## Writes the profile. Returns false (and writes nothing) for a read-only profile or when the disk refuses.
static func save(profile: PlayerProfile, path: String = PATH) -> bool:
	if profile.read_only:
		return false
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	profile.version = PlayerProfile.CURRENT_VERSION
	f.store_string(JSON.stringify(profile.to_dict(), "\t"))
	f.flush()
	f.close()
	# Keep the last good file, but never replace a good backup with a damaged file.
	if FileAccess.file_exists(path) and not _read_dict(path).is_empty():
		_copy(path, backup_path(path))
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_path)
	return DirAccess.rename_absolute(abs_tmp, abs_path) == OK


## Loads the profile at `path` for the content in `db`. Never fails: the worst case is a fresh profile.
static func load_from(db: ContentDb, path: String = PATH, new_seed: int = -1) -> LoadResult:
	var res := LoadResult.new()
	var data := _read_dict(path)
	var from_backup := false
	if data.is_empty() and FileAccess.file_exists(path):
		res.kept_as = _set_aside(path)
		res.status = Status.DAMAGED
	if data.is_empty():
		data = _read_dict(backup_path(path))
		from_backup = not data.is_empty()
	if data.is_empty():
		res.profile = PlayerProfile.new_game(db, new_seed if new_seed >= 0 else random_seed())
		if res.status != Status.DAMAGED:
			res.status = Status.NEW
		return res
	var mig := ProfileMigration.upgrade(data)
	if mig.too_new:
		res.profile = PlayerProfile.from_dict(mig.data)
		res.profile.read_only = true
		res.profile.sanitize(db)
		res.status = Status.FUTURE
		return res
	if mig.migrated() and not from_backup and FileAccess.file_exists(path):
		_copy(path, "%s.v%d.bak" % [path.get_basename(), mig.from_version])
	res.profile = PlayerProfile.from_dict(mig.data)
	if res.profile.reward_seed <= 0:
		res.profile.reward_seed = new_seed if new_seed >= 0 else random_seed()
	res.repaired = res.profile.sanitize(db)
	res.profile.backfill_rewards(db)
	if from_backup:
		res.status = Status.RECOVERED
	elif mig.migrated():
		res.status = Status.MIGRATED
	else:
		res.status = Status.OK
	return res


static func backup_path(path: String) -> String:
	return path + ".bak"


## A one-line message for the main menu, or "" when nothing needs saying.
static func note_for(res: LoadResult) -> String:
	match res.status:
		Status.RECOVERED:
			return "Your progress file was damaged; the last backup was loaded."
		Status.DAMAGED:
			return "Your progress file was damaged and could not be read; a new profile was started. The old file was kept as %s." % res.kept_as.get_file()
		Status.FUTURE:
			return "Your progress file comes from a newer version of the game. It is shown as it is but will not be changed."
	return ""


## A fresh reward seed.
static func random_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(1, MAX_SEED)


## The parsed JSON object in the file, or {} when the file is missing, empty, not JSON or not an object.
static func _read_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


static func _copy(from_path: String, to_path: String) -> bool:
	return DirAccess.copy_absolute(ProjectSettings.globalize_path(from_path), ProjectSettings.globalize_path(to_path)) == OK


## Renames a damaged file out of the way (never deletes it); returns its new path.
static func _set_aside(path: String) -> String:
	var target := "%s.corrupt-%d.json" % [path.get_basename(), int(Time.get_unix_time_from_system())]
	var n := 1
	while FileAccess.file_exists(target):
		target = "%s.corrupt-%d-%d.json" % [path.get_basename(), int(Time.get_unix_time_from_system()), n]
		n += 1
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(target))
	return target
