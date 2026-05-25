# MyWebApp - Simple Inventory Service

## Варіант індивідуального завдання
N = 20

**Розрахунки:**
* V2 = (20 % 2) + 1 = 1 -> Спосіб конфігурації: Аргументи командного рядка. База даних: MariaDB.
* V3 = (20 % 3) + 1 = 3 -> Тематика: Simple Inventory.
* V5 = (20 % 5) + 1 = 1 -> Порт застосунку: 8080.

## Документація по розробленому веб-застосунку
**Призначення застосунку:**
`mywebapp` - це простий сервіс для ведення обліку обладнання (Simple Inventory). Дозволяє переглядати список предметів, додавати нові записи та переглядати детальну інформацію про конкретний предмет.

**Середовище для розробки:**
* Node.js (v20+)
* MariaDB
* npm пакети: `express`, `mariadb`, `minimist`

**Як запустити локально:**
1. Клонувати репозиторій.
2. Виконати `npm install`.
3. Виконати міграцію: `node migrate.js --db_user=root --db_pass=root --db_name=inventory_db`
4. Запустити сервер: `node app.js --port=8080 --db_user=root --db_pass=root --db_name=inventory_db`

## Документація по API-ендпоінтах
Застосунок підтримує `text/html` або `application/json` для бізнес-логіки:
* `GET /` — Кореневий ендпоінт. Віддає лише `text/html` зі списком доступних API.
* `GET /items` — Виводить список усіх предметів в інвентарі (id, name).
* `POST /items` — Створює новий запис. Тіло запиту: `name`, `quantity`.
* `GET /items/<id>` — Виводить детальну інформацію по запису (id, name, quantity, created_at).
* `GET /health/alive` — Перевірка доступності сервісу (HTTP 200 OK).
* `GET /health/ready` — Перевірка підключення до БД (HTTP 200 OK або 500).

*health-ендпоінти доступні лише локально на ВМ і заблоковані ззовні через Nginx.*

## CI/CD Pipeline
 
Пайплайн складається з 4 джобів які виконуються послідовно:
 
```
lint + test → build-and-push → deploy
```
 
### Тригери
 
| Подія | lint | test | build-and-push | deploy |
|---|---|---|---|---|
| Push в `main` | ✅ | ✅ | ✅ | ❌ |
| Pull Request в `main` | ✅ | ✅ | ❌ | ❌ |
| Annotated tag `v*` | ✅ | ✅ | ✅ | ✅ |
 
### Джоби
 
**lint** — статичний аналіз коду:
- ESLint — аналіз JavaScript
- Hadolint — аналіз Dockerfile
- Yamllint — аналіз YAML файлів
**test** — автоматичні тести:
- Jest з покриттям коду (мінімум 40%)
- Артефакт зі звітом покриття завантажується для комітів в `main`
**build-and-push** — збірка Docker образу:
- Публікується в GitHub Container Registry (`ghcr.io`)
- Теги для коміту в `main`: `latest`, `sha-<full-commit-hash>`
- Теги для annotated tag: `stable`, `<tag>`
**deploy** — розгортання на self-hosted runner:
- Виконується тільки на annotated tags
- Пулить новий образ і перезапускає systemd сервіс
- Верифікує доступність сервісу та коректність налаштування Nginx
### Branch Protection Rules
 
Злиття в `main` заблоковано якщо не пройшли `lint` і `test`.
 
## Terraform + Ansible

### Архітектура

```
client → VM1 worker (nginx → app:8080) → VM2 db (MariaDB:3306)
```

Два вузли в межах Host-Only мережі VirtualBox (`192.168.56.0/24`):
- **VM1 `worker-vm`** (`192.168.56.104`) — nginx reverse proxy + Node.js застосунок
- **VM2 `db-vm`** (`192.168.56.103`) — MariaDB база даних

### Вимоги

- VirtualBox 7.2.8+
- Terraform 1.x
- Ansible
- WSL2 (Ubuntu)
- Vagrant box: `generic/ubuntu2204`

### Етап 1: Terraform

```bash
cd iac/terraform
terraform init
terraform apply
```

> **Примітка:** Провайдер `terra-farm/virtualbox` на Windows не може автоматично зчитати IP через відсутність VirtualBox Guest Additions в образі. Після створення VM необхідно вручну активувати Host-Only інтерфейс на кожній VM:
> ```bash
> sudo dhclient eth1
> ```
> Потім знайти IP через VirtualBox DHCP leases і оновити `inventory.ini`.

### Етап 2: Ansible

Перед запуском скопіювати SSH ключ на обидві VM:

```bash
ssh-copy-id -i ~/.ssh/ansible_key.pub vagrant@<worker_ip>
ssh-copy-id -i ~/.ssh/ansible_key.pub vagrant@<db_ip>
```

Оновити IP в `iac/ansible/inventory.ini`:

```ini
[workers]
worker_node ansible_host=192.168.56.104 ansible_user=vagrant

[db]
db_node ansible_host=192.168.56.103 ansible_user=vagrant
```

Запустити плейбук:

```bash
cd iac/ansible
ansible-playbook playbook.yml
```

### Що робить Ansible

**Роль `base`** (всі VM): створює юзерів `teacher`, `student`, файл `/home/student/gradebook`.

**Роль `db`** (db-vm): встановлює MariaDB, створює БД `inventory_db` і юзера `app`, налаштовує прослуховування на Host-Only IP.

**Роль `app`** (worker-vm): встановлює Node.js, копіює застосунок, створює юзерів `app` і `operator`, налаштовує systemd сервіс.

**Роль `nginx`** (worker-vm): встановлює nginx, налаштовує reverse proxy, блокує `/health` ззовні.

### Перевірка ідемпотентності

Повторний запуск `ansible-playbook playbook.yml` повертає майже всі таски зі статусом `ok`.

### Тестування системи

```bash
# Список предметів
curl http://192.168.56.104/items

# Health checks (локально на worker)
ssh vagrant@192.168.56.104 "curl -s http://localhost/health/alive"
ssh vagrant@192.168.56.104 "curl -s http://localhost/health/ready"
```

### Користувачі

| Користувач | VM | Права |
|---|---|---|
| `ansible` / `vagrant` | всі | sudo без пароля (для автоматизації) |
| `teacher` | всі | sudo з паролем `12345678` |
| `student` | всі | звичайний юзер |
| `app` | worker | системний, запускає застосунок |
| `operator` | worker | обмежений sudo (тільки mywebapp та nginx) |