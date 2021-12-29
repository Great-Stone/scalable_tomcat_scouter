output "server_ip" {
  // value = aws_instance.server.public_ip
  value = aws_eip.server.public_ip
}

output "client_ubuntu_ips" {
  // value = aws_instance.client.*.private_ip
  value = aws_instance.ubuntu.*.public_ip
}

output "client_windows_ips" {
  // value = aws_instance.client.*.private_ip
  value = aws_instance.windows.*.public_ip
}

output "for_windows" {
  value = "SuperS3cr3t!!!!"
}