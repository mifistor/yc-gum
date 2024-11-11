# yc-gum
Генератор готового к использованию terraform-манифеста. Скрипт использует YC CLI для генерации манифеста, поэтому убедитесь, что он установлен и создан профиль по [инструкции](https://yandex.cloud/ru/docs/cli/operations/profile/profile-create)

# How to use
Скачайте и настройте Terraform по [инструкции](https://yandex.cloud/ru/docs/tutorials/infrastructure-management/terraform-quickstart#install-terraform).

- Создайте новую директорию и перейдите туда: `mkdir terraform-stend && cd terraform-stend`
- Клонируйте репозиторий в пустую директорию: `git clone https://github.com/mifistor/yc-gum .` 
- Сделайте скрипт исполняемым: `chmod +x terraform-init.sh`
- Запустите скрипт: `./terraform-init.sh`
- Скрипт предожит выбрать профиль YC, Облако и другие параметры. Выбирать варианты можно при помощи клавиш управления курсором, либо просто начните печатать нужное значение
- После завершения работы скрипт создаст файл providers.tf, main.tf и файл с расширением json, которое содержит экспортированный сервисный аккаунт, от имени которого будет работать Terraform.
- Инициируйте terraform при помощи команды `terraform init`
- Манифест можно подправить под себя, либо сразу применить при помощи `terraform apply`


# Внешние зависимости

Скрипт требует для своей установки утилиту gum. Скачать и установить её можно по [инструкции](https://github.com/charmbracelet/gum#installation)
Скрипт ищет ssh-ключи в домашней директории в папке .ssh, поэтому если их там нет, сгенерируйте их по [инструкции](https://yandex.cloud/ru/docs/glossary/ssh-keygen?ysclid=m2zum1m87n550795629#generate)
