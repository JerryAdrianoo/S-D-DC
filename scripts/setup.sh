#!/bin/bash

# Script de Setup para o Sistema de Incident Management

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Incident Management System Setup${NC}"
echo -e "${BLUE}=====================================${NC}\n"

# Função para verificar se comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verificar dependências
echo -e "${YELLOW}📋 Checking dependencies...${NC}"

if ! command_exists docker; then
    echo -e "${RED}❌ Docker not found. Please install Docker first.${NC}"
    echo -e "${YELLOW}Installation guide: https://docs.docker.com/get-docker/${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Docker found${NC}"
fi

if ! command_exists docker-compose; then
    echo -e "${RED}❌ Docker Compose not found. Please install Docker Compose first.${NC}"
    echo -e "${YELLOW}Installation guide: https://docs.docker.com/compose/install/${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Docker Compose found${NC}"
fi

if ! command_exists curl; then
    echo -e "${RED}❌ curl not found. Please install curl first.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ curl found${NC}"
fi

echo

# Criar estrutura de diretórios
echo -e "${YELLOW}📁 Creating project structure...${NC}"

mkdir -p web/html
mkdir -p api/routes
mkdir -p database
mkdir -p logs
mkdir -p scripts

echo -e "${GREEN}✅ Directory structure created${NC}\n"

# Criar Dockerfile para Web (Nginx)
echo -e "${YELLOW}🐳 Creating Web Dockerfile...${NC}"
cat > web/Dockerfile << 'EOF'
FROM nginx:alpine

# Instalar curl para health checks
RUN apk add --no-cache curl

# Copiar configuração personalizada
COPY nginx.conf /etc/nginx/nginx.conf
COPY html/ /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

# Criar configuração do Nginx
cat > web/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
            try_files $uri $uri/ =404;
        }
        
        location /api/ {
            proxy_pass http://api:3000/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
        
        # Health check endpoint
        location /nginx-health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

# Criar página HTML da dashboard
cat > web/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Incident Management Dashboard</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f4f4f4;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            padding: 20px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            color: #333;
            margin-bottom: 30px;
        }
        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }
        .service-card {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            border-left: 4px solid #28a745;
        }
        .service-name {
            font-size: 1.2em;
            font-weight: bold;
            margin-bottom: 10px;
        }
        .status-ok { color: #28a745; }
        .status-error { color: #dc3545; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚨 Incident Management Dashboard</h1>
            <p>Sistema de Monitoramento de Serviços</p>
        </div>
        
        <div class="status-grid">
            <div class="service-card">
                <div class="service-name">Web Service</div>
                <div class="status-ok">✅ Online</div>
                <p>Nginx - Porta 8080</p>
            </div>
            
            <div class="service-card">
                <div class="service-name">API Service</div>
                <div class="status-ok">✅ Online</div>
                <p>Node.js - Porta 3000</p>
            </div>
            
            <div class="service-card">
                <div class="service-name">Database</div>
                <div class="status-ok">✅ Online</div>
                <p>PostgreSQL - Porta 5432</p>
            </div>
        </div>
        
        <div style="margin-top: 30px; text-align: center;">
            <p><strong>Sistema de Incident Management em funcionamento!</strong></p>
            <p>Use o script monitor.sh para iniciar o monitoramento automatizado.</p>
        </div>
    </div>
</body>
</html>
EOF

echo -e "${GREEN}✅ Web files created${NC}\n"

# Criar Dockerfile para API (Node.js)
echo -e "${YELLOW}🐳 Creating API Dockerfile...${NC}"
cat > api/Dockerfile << 'EOF'
FROM node:16-alpine

# Instalar curl para health checks
RUN apk add --no-cache curl

WORKDIR /app

# Copiar package.json
COPY package.json ./

# Instalar dependências
RUN npm install

# Copiar código fonte
COPY . .

# Criar diretório de logs
RUN mkdir -p logs

EXPOSE 3000

CMD ["npm", "start"]
EOF

# Criar package.json para API
cat > api/package.json << 'EOF'
{
  "name": "incident-management-api",
  "version": "1.0.0",
  "description": "API for Incident Management System",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.8.0",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "nodemon": "^2.0.20"
  }
}
EOF

# Criar servidor Node.js
cat > api/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Configuração do banco
const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'incidents',
    user: process.env.DB_USER || 'incident_user',
    password: process.env.DB_PASS || 'incident_pass',
});

// Função para simular falhas ocasionais (para testes)
const shouldSimulateFailure = () => {
    return Math.random() < 0.1; // 10% chance de falha
};

// Health check endpoint
app.get('/health', (req, res) => {
    if (shouldSimulateFailure()) {
        return res.status(500).json({ 
            status: 'error',
            message: 'Simulated API failure',
            timestamp: new Date().toISOString()
        });
    }
    
    res.json({ 
        status: 'ok',
        service: 'incident-management-api',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Database health check
app.get('/db-health', async (req, res) => {
    try {
        const result = await pool.query('SELECT NOW()');
        res.json({ 
            status: 'ok',
            database: 'connected',
            timestamp: result.rows[0].now
        });
    } catch (error) {
        res.status(500).json({ 
            status: 'error',
            database: 'disconnected',
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// Endpoint para listar incidentes
app.get('/incidents', async (req, res) => {
    try {
        const result = await pool.query(
            'SELECT * FROM incidents ORDER BY created_at DESC LIMIT 50'
        );
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Endpoint para criar incidente
app.post('/incidents', async (req, res) => {
    const { service_name, severity, description } = req.body;
    
    try {
        const result = await pool.query(
            'INSERT INTO incidents (service_name, severity, description) VALUES ($1, $2, $3) RETURNING *',
            [service_name, severity, description]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Iniciar servidor
app.listen(PORT, () => {
    console.log(`🚀 API Server running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
    console.log(`DB Health check: http://localhost:${PORT}/db-health`);
});
EOF

echo -e "${GREEN}✅ API files created${NC}\n"

# Criar script SQL de inicialização do banco
echo -e "${YELLOW}🗄️ Creating database initialization...${NC}"
cat > database/init.sql << 'EOF'
-- Criar tabela de incidentes
CREATE TABLE IF NOT EXISTS incidents (
    id SERIAL PRIMARY KEY,
    service_name VARCHAR(100) NOT NULL,
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    description TEXT,
    status VARCHAR(20) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'INVESTIGATING', 'RESOLVED', 'CLOSED')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL
);

-- Criar tabela de status dos serviços
CREATE TABLE IF NOT EXISTS service_status (
    id SERIAL PRIMARY KEY,
    service_name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('UP', 'DOWN', 'DEGRADED')),
    response_time INTEGER, -- em milissegundos
    checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inserir alguns dados de exemplo
INSERT INTO incidents (service_name, severity, description, status) VALUES
('web', 'LOW', 'Exemplo de incidente resolvido', 'RESOLVED'),
('api', 'MEDIUM', 'Exemplo de incidente em investigação', 'INVESTIGATING'),
('database', 'HIGH', 'Exemplo de incidente crítico', 'OPEN');

-- Criar índices para performance
CREATE INDEX IF NOT EXISTS idx_incidents_created_at ON incidents(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_incidents_service ON incidents(service_name);
CREATE INDEX IF NOT EXISTS idx_service_status_checked_at ON service_status(checked_at DESC);

-- Função para atualizar timestamp automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$ language 'plpgsql';

-- Trigger para atualizar updated_at automaticamente
CREATE TRIGGER update_incidents_updated_at BEFORE UPDATE ON incidents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMIT;
EOF

echo -e "${GREEN}✅ Database files created${NC}\n"

# Criar script de limpeza
echo -e "${YELLOW}🧹 Creating cleanup script...${NC}"
cat > scripts/cleanup.sh << 'EOF'
#!/bin/bash

echo "🧹 Cleaning up Incident Management System..."

# Parar containers
docker-compose down

# Remover volumes (opcional - descomente se quiser limpar dados)
# docker-compose down -v

# Limpar logs
rm -rf logs/*

echo "✅ Cleanup completed!"
EOF

chmod +x scripts/cleanup.sh

# Criar script de incident handler
cat > scripts/incident-handler.sh << 'EOF'
#!/bin/bash

# Script para lidar com incidentes específicos
# Este script é chamado pelo monitor quando incidentes são detectados

INCIDENT_TYPE="$1"
SERVICE_NAME="$2"
SEVERITY="$3"

echo "🚨 Handling incident: $INCIDENT_TYPE for service $SERVICE_NAME (Severity: $SEVERITY)"

case "$INCIDENT_TYPE" in
    "service_down")
        echo "🔄 Attempting to restart service: $SERVICE_NAME"
        docker-compose restart "$SERVICE_NAME"
        ;;
    "high_resource_usage")
        echo "📊 Checking resource usage..."
        docker stats --no-stream
        ;;
    "database_connection_failed")
        echo "🔧 Checking database connectivity..."
        docker-compose exec database pg_isready -U incident_user
        ;;
    *)
        echo "❓ Unknown incident type: $INCIDENT_TYPE"
        ;;
esac

echo "✅ Incident handling completed for $SERVICE_NAME"
EOF

chmod +x scripts/incident-handler.sh

echo -e "${GREEN}✅ Additional scripts created${NC}\n"

# Tornar scripts executáveis
chmod +x scripts/monitor.sh

echo -e "${GREEN}🎉 Setup completed successfully!${NC}\n"

echo -e "${BLUE}📋 Next steps:${NC}"
echo -e "1. ${YELLOW}docker-compose up -d${NC} - Start all services"
echo -e "2. ${YELLOW}./scripts/monitor.sh${NC} - Start monitoring"
echo -e "3. ${YELLOW}Open http://localhost:8080${NC} - View dashboard"
echo -e "4. ${YELLOW}./scripts/monitor.sh --help${NC} - See monitoring options"
echo -e "5. ${YELLOW}./scripts/cleanup.sh${NC} - Clean up when done"

echo -e "\n${GREEN}✨ Your Incident Management System is ready!${NC}"