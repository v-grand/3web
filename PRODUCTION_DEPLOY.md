# Production Deployment Guide

## 🚀 Развертывание в Production через Docker

### Предварительные требования

- ✅ Docker и Docker Compose установлены на сервере
- ✅ Домен настроен и указывает на ваш сервер
- ✅ (Рекомендуется) SSL сертификат настроен

---

## 📝 Шаг 1: Подготовка конфигурации

### 1.1 Создайте production .env файл

```bash
# Скопируйте шаблон
cp backend/.env.production backend/.env.production.local

# Отредактируйте файл
nano backend/.env.production.local
```

**Обязательно измените:**

```env
# Сгенерируйте надежный SECRET_KEY (минимум 50 символов)
SECRET_KEY=$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')

# Укажите ваш домен
DOMAIN=yourdomain.com

# Настройте базу данных с надежным паролем
DATABASE_URL=postgres://postgres:STRONG_PASSWORD_HERE@db:5432/db

# Настройте email (например, через Gmail, Mailgun, SendGrid)
EMAIL_URL=smtp://username:password@smtp.gmail.com:587/?ssl=True

# Настройте Sentry для мониторинга ошибок
SENTRY_DSN=https://xxxxx@sentry.io/xxxxx
```

### 1.2 Установите пароль базы данных

```bash
# Создайте .env в корне проекта для docker-compose
echo "POSTGRES_PASSWORD=YOUR_STRONG_DB_PASSWORD" > .env
```

---

## 🔧 Шаг 2: Сборка и запуск

### 2.1 Соберите production образ

```bash
# Используйте BuildKit для оптимизации
DOCKER_BUILDKIT=1 docker-compose -f docker-compose.prod.yml build --no-cache
```

### 2.2 Запустите контейнеры

```bash
docker-compose -f docker-compose.prod.yml up -d
```

### 2.3 Выполните миграции

```bash
docker-compose -f docker-compose.prod.yml exec web python manage.py migrate
```

### 2.4 Создайте суперпользователя

```bash
docker-compose -f docker-compose.prod.yml exec web python manage.py createsuperuser
```

### 2.5 Соберите статику (уже выполнено в Dockerfile, но на всякий случай)

```bash
docker-compose -f docker-compose.prod.yml exec web python manage.py collectstatic --noinput
```

---

## 🔐 Шаг 3: Настройка SSL (Let's Encrypt)

### Вариант A: С Nginx Proxy

Используйте nginx-proxy + letsencrypt-companion:

```bash
# docker-compose.ssl.yml
version: '3.8'

services:
  nginx-proxy:
    image: nginxproxy/nginx-proxy
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/tmp/docker.sock:ro
      - certs:/etc/nginx/certs:ro
      - vhost:/etc/nginx/vhost.d
      - html:/usr/share/nginx/html
    networks:
      - proxy

  letsencrypt:
    image: nginxproxy/acme-companion
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - certs:/etc/nginx/certs
      - vhost:/etc/nginx/vhost.d
      - html:/usr/share/nginx/html
    environment:
      DEFAULT_EMAIL: admin@yourdomain.com
    depends_on:
      - nginx-proxy
    networks:
      - proxy

  web:
    # ... ваш web сервис
    environment:
      VIRTUAL_HOST: yourdomain.com
      LETSENCRYPT_HOST: yourdomain.com
      LETSENCRYPT_EMAIL: admin@yourdomain.com
    networks:
      - app-network
      - proxy

networks:
  proxy:
    external: true
  app-network:
    internal: true

volumes:
  certs:
  vhost:
  html:
```

### Вариант B: С Certbot

```bash
# Установите certbot
apt-get install certbot

# Получите сертификат
certbot certonly --standalone -d yourdomain.com

# Сертификаты будут в /etc/letsencrypt/live/yourdomain.com/
```

---

## 📊 Шаг 4: Мониторинг и логи

### Просмотр логов

```bash
# Все логи
docker-compose -f docker-compose.prod.yml logs -f

# Конкретный сервис
docker-compose -f docker-compose.prod.yml logs -f web
docker-compose -f docker-compose.prod.yml logs -f db

# Последние 100 строк
docker-compose -f docker-compose.prod.yml logs --tail=100 web
```

### Статус сервисов

```bash
docker-compose -f docker-compose.prod.yml ps
```

### Использование ресурсов

```bash
docker stats
```

---

## 🔄 Шаг 5: Обновление приложения

### Обновление кода

```bash
# 1. Получите последние изменения
git pull origin master

# 2. Пересоберите образ
DOCKER_BUILDKIT=1 docker-compose -f docker-compose.prod.yml build

# 3. Остановите старые контейнеры
docker-compose -f docker-compose.prod.yml down

# 4. Запустите новые
docker-compose -f docker-compose.prod.yml up -d

# 5. Выполните миграции
docker-compose -f docker-compose.prod.yml exec web python manage.py migrate

# 6. Соберите статику
docker-compose -f docker-compose.prod.yml exec web python manage.py collectstatic --noinput --clear
```

### Zero-downtime deployment

```bash
# Используйте rolling update
docker-compose -f docker-compose.prod.yml up -d --scale web=2 --no-recreate
docker-compose -f docker-compose.prod.yml up -d --scale web=1
```

---

## 💾 Шаг 6: Резервное копирование

### Backup базы данных

```bash
# Создать backup
docker-compose -f docker-compose.prod.yml exec db pg_dump -U postgres db > backup_$(date +%Y%m%d_%H%M%S).sql

# Или с gzip
docker-compose -f docker-compose.prod.yml exec db pg_dump -U postgres db | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

### Restore базы данных

```bash
# Из SQL файла
docker-compose -f docker-compose.prod.yml exec -T db psql -U postgres db < backup.sql

# Из gzip
gunzip -c backup.sql.gz | docker-compose -f docker-compose.prod.yml exec -T db psql -U postgres db
```

### Backup медиа файлов

```bash
# Архивировать data папку
tar -czf media_backup_$(date +%Y%m%d).tar.gz ./data/media/

# Загрузить в S3 (если используется)
aws s3 cp media_backup.tar.gz s3://your-bucket/backups/
```

### Автоматический backup (cron)

```bash
# Добавьте в crontab
crontab -e

# Backup каждый день в 2:00
0 2 * * * cd /path/to/project && docker-compose -f docker-compose.prod.yml exec db pg_dump -U postgres db | gzip > /backups/db_$(date +\%Y\%m\%d).sql.gz
```

---

## 🔧 Настройка системы

### Автозапуск при перезагрузке сервера

Docker контейнеры с `restart: unless-stopped` запустятся автоматически.

Убедитесь, что Docker запускается при старте:

```bash
sudo systemctl enable docker
```

### Настройка файрвола (UFW)

```bash
# Разрешите необходимые порты
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

### Ограничение ресурсов (опционально)

В `docker-compose.prod.yml` добавьте:

```yaml
services:
  web:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 512M
```

---

## 📈 Оптимизация Production

### 1. Используйте Redis для кеширования

```bash
# В docker-compose.prod.yml раскомментируйте redis

# В backend/.env.production:
CACHE_URL=redis://redis:6379/1
```

### 2. Настройте CDN для статики

Используйте CloudFlare, AWS CloudFront или подобное для статических файлов.

### 3. Настройте S3 для медиа

```env
# В backend/.env.production:
DEFAULT_STORAGE_DSN=s3://AWS_KEY:AWS_SECRET@bucket-name/?region=eu-central-1
```

### 4. Мониторинг

- **Sentry** - для ошибок (обязательно!)
- **Prometheus + Grafana** - для метрик
- **Uptime Robot** - для проверки доступности

---

## 🚨 Устранение неполадок

### Контейнер не запускается

```bash
# Проверьте логи
docker-compose -f docker-compose.prod.yml logs web

# Проверьте конфигурацию
docker-compose -f docker-compose.prod.yml config
```

### База данных недоступна

```bash
# Проверьте статус
docker-compose -f docker-compose.prod.yml ps db

# Проверьте подключение
docker-compose -f docker-compose.prod.yml exec db psql -U postgres -c "SELECT 1"
```

### Нет места на диске

```bash
# Очистите старые образы
docker system prune -a

# Очистите volumes (ОСТОРОЖНО!)
docker volume prune
```

### High memory usage

```bash
# Проверьте использование
docker stats

# Ограничьте память в docker-compose.prod.yml
```

---

## 📋 Чеклист Production

- [ ] SECRET_KEY изменен на случайное значение
- [ ] DEBUG=False
- [ ] ALLOWED_HOSTS настроен правильно
- [ ] База данных с надежным паролем
- [ ] SSL сертификат установлен
- [ ] Email настроен и протестирован
- [ ] Sentry настроен для мониторинга ошибок
- [ ] Настроен регулярный backup БД
- [ ] Файрвол настроен
- [ ] Логирование работает
- [ ] Мониторинг доступности настроен
- [ ] Документация обновлена

---

## 🔗 Полезные команды

```bash
# Перезапуск сервиса без downtime
docker-compose -f docker-compose.prod.yml restart web

# Проверка health status
docker-compose -f docker-compose.prod.yml exec web python manage.py check --deploy

# Запуск shell в контейнере
docker-compose -f docker-compose.prod.yml exec web bash

# Django shell
docker-compose -f docker-compose.prod.yml exec web python manage.py shell

# Очистка кеша Django CMS
docker-compose -f docker-compose.prod.yml exec web python manage.py clear_cache
```
