class_name JobManager
extends RefCounted

var _definitions: Dictionary = {}
var _jobs: Dictionary = {}

func register_definition(definition: JobDefinition) -> bool:
	if definition == null or not definition.is_valid():
		return false
	_definitions[definition.id] = definition
	return true

func get_definition(definition_id: String) -> JobDefinition:
	return _definitions.get(definition_id, null)

func create_job(job_id: String, definition_id: String) -> JobState:
	if job_id.is_empty() or _jobs.has(job_id) or not _definitions.has(definition_id):
		return null
	var state := JobState.new(job_id, definition_id)
	_jobs[job_id] = state
	return state

func assign_worker(job_id: String, worker_id: String) -> bool:
	var job: JobState = _jobs.get(job_id, null)
	if job == null:
		return false
	job.assigned_worker_id = worker_id
	job.active = not worker_id.is_empty()
	return true

func unassign_worker(job_id: String) -> bool:
	return assign_worker(job_id, "")

func get_job(job_id: String) -> JobState:
	return _jobs.get(job_id, null)
