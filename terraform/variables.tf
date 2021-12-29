variable "default_tags" {
  type = map(any)
  default = {}
}

variable "region" {
  default = "ap-northeast-2"
}

variable "prefix" {
  default = "test"
}

variable "client_ubuntu_count" {}
variable "client_windows_count" {}