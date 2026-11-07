extends "res://tests/act1_recovery_branch_test.gd"

func _initialize() -> void:
	host_name = "hive"
	receipt["host"] = host_name
	super._initialize()
