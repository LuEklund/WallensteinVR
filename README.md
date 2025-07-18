# 🛠️ WallensteinVR

## ⚙️ Installation

Great resource [here](https://dochavez.github.io/Documenting-with-Docusaurus-V2.-/docs/monado/)

_NOTE: The <a href="https://vulkan.lunarg.com/sdk/home" target="_blank"><img src="https://vulkan.lunarg.com/img/vulkan/vulkan-red.svg" height="22" style="vertical-align: text-bottom"/> SDK</a> is required._

### 🪟 Windows

```sh
Idk, use linux tbh
```

### 🐧 Linux

#### 📦 Debian/Ubuntu

```sh
sudo apt update
sudo apt install libopenxr-loader1 libopenxr-dev xr-hardware openxr-layer-corevalidation
```

or

```sh
wget -nv https://download.opensuse.org/repositories/home:rpavlik:monado/Debian-10/Release.key -O obs-monado.asc
sudo mv obs-monado.asc /etc/apt/trusted.gpg.d/

echo 'deb http://download.opensuse.org/repositories/home:/rpavlik:/monado/Debian-10/ /' | sudo tee /etc/apt/sources.list.d/monado.list

sudo apt update
sudo apt install openxr-layer-corevalidation openxr-layer-apidump xr-hardware openxr-layer-corevalidation
```

#### 📦 Arch

```sh
sudo pacman -S openxr
```

### 🧩 Runtimes

##### Monado — _Recommended_

<a href="https://monado.dev/" style="text-decoration: none; display: inline-flex; align-items: center;">
  <span style="background-color: #7928CA; color: white; font-weight: 600; padding: 2px 6px; border-radius: 3px; font-family: Arial, sans-serif; display: inline-flex; align-items: center; font-size: 10px;">
    <img 
      src="https://monado.dev/images/Monado_logo.svg" 
      alt="Monado logo" 
      width="20" 
      height="20" 
      style="margin-right: 4px; clip-path: inset(0 0 5px 0); object-fit: contain;"
    />
    Monado
  </span>
  <span style="color: white; font-weight: 600; font-family: Arial, sans-serif; margin-left: 6px; font-size: 10px;">
    .dev
  </span>
</a>

[Gitlab](https://gitlab.freedesktop.org/monado/monado) _Recommended_

[![Monado Repo](https://img.shields.io/badge/Monado-GitHub-black?style=flat&logo=github)](https://github.com/mateosss/monado)

APT

```sh
sudo apt install libopenxr1-monado monado-cli monado-gui
```

Build from source

```sh
git clone https://gitlab.freedesktop.org/monado/monado
cd monado
mkdir build
cd build
cmake ..
sudo make install
```

Run

```sh
rm -rf /run/user/1000/monado_comp_ipc && monado-service --verbose # --null to run with a virtual device (no real hardware)
```

##### Steam VR

[<img src="https://upload.wikimedia.org/wikipedia/commons/8/83/Steam_icon_logo.svg" width="20"/> Steam VR](https://store.steampowered.com/app/250820/SteamVR/)
