#!/bin/sh

# Created by @mifistor (telegram)
# https://github.com/mifistor/yc-gum

# Is YC CLI installed?
if ! command -v yc &> /dev/null
then
    echo "YC CLI not found"
    echo "CLI installation: https://yandex.cloud/en/docs/cli/"
    exit 1
fi

# Is gum installed?
if ! command -v gum &> /dev/null
then
    echo "Gum not found"
    echo "How to install: https://github.com/charmbracelet/gum#installation"
    exit 1
fi

gum style --border normal --margin "1" --padding "1 2" --border-foreground 212 "This master generate default tf config using yc"

PROFILE=$(yc config profile list | sed 's/ACTIVE//g' | gum filter --limit 1 --placeholder "Select YC CLI profile")
# Since the scope is optional, wrap it in parentheses if it has a value.
# test -n "$SCOPE" && SCOPE="($SCOPE)"

CLOUD_NAME=$(yc --profile=$PROFILE resource-manager cloud list --jq '.[].name' | gum filter --limit 1 --placeholder "Type or select cloud")
FOLDER_NAME=$(yc --profile=$PROFILE resource-manager folder list --jq '.[].name' | gum filter --limit 1 --placeholder "Select folder")
FOLDER_ID=$(yc --profile=$PROFILE resource-manager folder get --name=$FOLDER_NAME --jq '.id')
CLOUD_ID=$(yc --profile=$PROFILE resource-manager cloud get --name=$CLOUD_NAME --jq '.id')
ZONE=$(yc --profile $PROFILE compute zone list --jq='map(select(.status == "UP")) | .[].id' | gum filter --limit 1 --placeholder "Select default zone")

if [ -z "$(yc --profile=$PROFILE iam service-account list --cloud-id=$CLOUD_ID --jq '.[].name')" ]; then
  echo "No service account found in ${CLOUD_NAME}. I create service account with name terraform and role admin to cloud ${CLOUD_NAME}"
  gum confirm "No service account found in cloud ${CLOUD_NAME}. Create it and binding role admin to cloud?" && CREATED_SA=$(yc iam service-account create --name terraform --jq='.id' --no-user-output) && \
 yc --profile ${PROFILE} resource-manager cloud add-access-binding ${CLOUD_ID}\
  --role admin \
  --subject serviceAccount:${CREATED_SA} --no-user-output || exit 1
fi

SELECTED_SA=$(yc --profile=$PROFILE iam service-account list --jq '.[].name' | gum filter --limit 1 --placeholder "Select service account")

gum spin --spinner dot --title "Creating authorized keys..." -- yc --profile $PROFILE iam key create --service-account-name $SELECTED_SA --folder-id $FOLDER_ID --output $SELECTED_SA.json

PROVIDER_MANIFEST=$(cat << EOF
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}
// Configure the Yandex.Cloud provider
provider "yandex" {
  service_account_key_file = "${SELECTED_SA}.json"
  cloud_id                 = "${CLOUD_ID}"
  folder_id                = "${FOLDER_ID}"
  zone                     = "${ZONE}"
}
EOF
)

echo "$PROVIDER_MANIFEST" > providers.tf

SELECTED_FAMILY=$(yc --profile $PROFILE compute image list --folder-id standard-images --jq '.[].family' | sort | uniq | gum filter --limit 1 --placeholder "Type image family, used latest version")
LATEST_IMAGE_FROM_FAMILY=$(yc --profile $PROFILE compute image get-latest-from-family $SELECTED_FAMILY --folder-id standard-images --jq '.id')

VM_MANIFEST=$(cat << EOF
  resource "yandex_compute_disk" "boot-disk-1" {
  name     = "boot-disk-1"
  type     = "network-hdd" # 
  zone     = "${ZONE}"
  size     = "20"
  image_id = "${LATEST_IMAGE_FROM_FAMILY}"
}

resource "yandex_compute_instance" "vm-${SELECTED_FAMILY}" {
  name = "vm-${SELECTED_FAMILY}"
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 2
    core_fraction = 100 # 20, 50, 100 More information here: https://yandex.cloud/ru/docs/compute/concepts/performance-levels
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-1.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:\${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
  description = "Created by terraform"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  description    = "Created by terraform"
  zone           = "${ZONE}"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

output "internal_ip_address_vm_${SELECTED_FAMILY}" {
  value = yandex_compute_instance.vm-${SELECTED_FAMILY}.network_interface.0.ip_address
}

output "ssh ubuntu@external_ip_address_vm_${SELECTED_FAMILY}" {
  value = yandex_compute_instance.vm-${SELECTED_FAMILY}.network_interface.0.nat_ip_address
}
EOF
)
echo "$VM_MANIFEST" > main.tf

echo "All done! Now edit main.tf for youself, run \`terraform init\` and \`terraform apply\` to create your resources" 
