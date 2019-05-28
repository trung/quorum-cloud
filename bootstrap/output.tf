output "data_dirs" {
  value = "${data.null_data_source.node_dir.*.inputs.dir}"
}

output "hash" {
  value = "${random_id.change.hex}"
}

output "prepare_network" {
  value = "${local.prepare_network}"
}

output "start_network" {
  value = "${local.start_network}"
}
