variable "project_id" {
  type = string
}

variable "location" {
  type = string
}
variable "dev-cpos" {
  type = string
}

variable "labels" {
  type = map
}

variable "cpos-dev-cidr-range" {
  type    = string
  default = "192.168.1.0/24"
}

variable "cpos-dev-iap-range-ssh" {
    type=list
    default=[ "35.235.240.0/20" ]
}

variable "cpos-dev-ssh" {
    type=list
    default=["22"]
}