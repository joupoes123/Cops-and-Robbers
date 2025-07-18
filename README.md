# Cops & Robbers - FiveM GTA V Roleplay Game Mode

**Cops & Robbers** is an open-source game mode for FiveM, designed to provide an immersive GTA V roleplay experience focused on the thrilling interaction between law enforcement and criminal elements.

## 🚀 Latest Version: 1.2.0 (July 2025)

### Major Features
- **50-Level Progression System** with prestige levels and role-specific rewards
- **Advanced Character Editor** with real-time preview and uniform presets
- **Dynamic Bounty System** with interactive bounty board for law enforcement
- **Enhanced Police Systems** including K9 units, speed radar, and SWAT operations
- **Advanced Criminal Operations** with EMP devices, power grid sabotage, and heist tools
- **Comprehensive Store System** with fixed transactions and real-time inventory updates
- **Challenge System** with daily/weekly objectives and seasonal events

## 🎮 Quick Start

### Installation
1. Clone or download the repository
2. Copy the `Cops-and-Robbers` folder to your server's `resources` directory
3. Add `start Cops-and-Robbers` to your `server.cfg`
4. Restart your server

### First Steps
1. **Join Server**: Connect to your FiveM server
2. **Select Role**: Press `F5` to choose between Cop or Robber
3. **Character Creation**: Press `F3` to customize your character
4. **Start Playing**: Begin earning XP through role-specific activities
5. **Check Progress**: Press `P` to view progression and challenges

## 🎯 Key Controls

| Key | Action |
|-----|--------|
| `F5` | Role selection menu |
| `F3` | Character editor |
| `P` | Progression menu |
| `M` | Inventory |
| `F1` | Cop menu / EMP device (robber) |
| `F2` | Robber menu / Admin panel |
| `G` | Deploy spike strips / Cuff player |
| `K` | Toggle K9 unit |
| `LEFT ALT` | Speed radar |

## 📚 Documentation

For detailed information, guides, and advanced features, visit our **[Wiki Documentation](docs/Home.md)**:

- **[Installation Guide](docs/Installation-Guide.md)** - Complete setup instructions
- **[Core Features](docs/Core-Features.md)** - Detailed feature overview
- **[Law Enforcement Systems](docs/Law-Enforcement-Systems.md)** - Police tools and mechanics
- **[Criminal Activities](docs/Criminal-Activities.md)** - Heist systems and criminal tools
- **[Admin Commands](docs/Admin-Commands.md)** - Server administration
- **[API Reference](docs/API-Reference.md)** - Development documentation

## 🔧 System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **FiveM Build** | 2372+ | 2944+ |
| **Server RAM** | 1GB | 2GB+ |
| **Storage** | 50MB | 100MB |
| **Players** | 1-32 | 32-128 |
| **Dependencies** | None | None |

## 🐳 Docker Deployment

### Prerequisites
- Docker and Docker Compose installed
- FiveM license key from [keymaster.fivem.net](https://keymaster.fivem.net/)

### Quick Start with Docker

1. Clone the repository:
```bash
git clone https://gitlab.axiomrp.dev/the-axiom-collective/cops-and-robbers.git
cd cops-and-robbers
```

2. Copy the environment file and configure your license key:
```bash
cp .env.example .env
# Edit .env and add your LICENSE_KEY
```

3. Start the server:
```bash
docker-compose up -d
```

4. Access txAdmin web interface at `http://localhost:40120` (if enabled)

### Docker Build Only

If you prefer to use docker run instead of docker-compose:

```bash
# Build the image
docker build -t cops-and-robbers .

# Run the container
docker run -d \
  --name cops-and-robbers-server \
  --restart=unless-stopped \
  -e LICENSE_KEY=your_license_key_here \
  -p 30120:30120/tcp \
  -p 30120:30120/udp \
  -p 40120:40120/tcp \
  -v cops_config:/config \
  -v cops_txdata:/txData \
  -v cops_playerdata:/opt/cfx-server/resources/cops-and-robbers/player_data \
  -it \
  cops-and-robbers
```

### Data Persistence

The Docker setup includes persistent volumes for:
- `/config` - FiveM server configuration
- `/txData` - txAdmin data and settings
- `/opt/cfx-server/resources/cops-and-robbers/player_data` - Player save files

### Environment Variables

- `LICENSE_KEY` (required) - Your FiveM license key
- `RCON_PASSWORD` (optional) - RCON password for server administration



## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details on:
- Bug reports and feature requests
- Code contributions and pull requests
- Documentation improvements
- Community support

## 📝 License

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.

## 🆘 Support & Community

- **GitHub Issues**: [Report bugs and request features](https://github.com/Indom-hub/Cops-and-Robbers/issues)
- **Discord Community**: [Join our Discord](https://discord.gg/Kw5ndrWXfT)
- **Development Forum**: [Axiom Development Forum](https://forum.axiomrp.dev/)

## 🏆 Acknowledgments

- **The Axiom Collective** - Original development team
- **FiveM Community** - Platform and development resources
- **Contributors** - Community members who have contributed code, testing, and feedback

---

**Let the chase begin!** 🚔💨🔫

*For comprehensive guides, advanced configuration, and detailed feature documentation, please visit our [Wiki](docs/Home.md).*
