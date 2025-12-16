terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

# Вставь свои данные сюда!
provider "yandex" {
  token     = "" # Оставь пустым, если авторизовался через yc init
  cloud_id  = "ВСТАВЬ_СВОЙ_CLOUD_ID"
  folder_id = "ВСТАВЬ_СВОЙ_FOLDER_ID"
  zone      = "ru-central1-a"
}

# 1. Создаем сеть
resource "yandex_vpc_network" "k8s-network" {
  name = "k8s-network"
}

# 2. Создаем подсеть
resource "yandex_vpc_subnet" "k8s-subnet" {
  name           = "k8s-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.k8s-network.id
  v4_cidr_blocks = ["10.0.0.0/16"]
}

# 3. Сервисный аккаунт для Кубера (чтобы он мог управлять ресурсами)
resource "yandex_iam_service_account" "k8s-sa" {
  name        = "k8s-robot"
  description = "Service account for Kubernetes"
}

# Раздаем права сервисному аккаунту
resource "yandex_resourcemanager_folder_iam_member" "editor" {
  folder_id = "ВСТАВЬ_СВОЙ_FOLDER_ID"
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "images-puller" {
  folder_id = "ВСТАВЬ_СВОЙ_FOLDER_ID"
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
}

# 4. Реестр контейнеров (куда будем лить Docker образы)
resource "yandex_container_registry" "my-reg" {
  name = "game-registry"
}

# 5. Сам кластер Kubernetes (Zonal - дешевле)
resource "yandex_kubernetes_cluster" "k8s-cluster" {
  name        = "game-cluster"
  network_id  = yandex_vpc_network.k8s-network.id

  master {
    version = "1.28" # Или актуальную версию
    zonal {
      zone      = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.k8s-subnet.id
    }
    public_ip = true # Чтобы мы могли к нему подключаться из GitHub
  }

  service_account_id      = yandex_iam_service_account.k8s-sa.id
  node_service_account_id = yandex_iam_service_account.k8s-sa.id
  
  release_channel = "RAPID"
}