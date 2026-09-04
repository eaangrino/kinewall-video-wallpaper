# KineWall — Video Wallpaper para Linux

[English](README.md)

**KineWall** es un plugin QML de fondo de pantalla para KDE Plasma 6 que reproduce un video local en bucle continuo y deshabilita explícitamente la pista de audio (`activeAudioTrack: -1`).

KineWall puede utilizarse tanto como **fondo de Plasma Desktop** como en la **pantalla de bloqueo de KDE Plasma (KScreenLocker)**.

También puede pausar automáticamente la reproducción cuando una ventana maximizada cubre el escritorio, evitando reproducir el video innecesariamente cuando el fondo no es visible. Esta pausa de rendimiento solo se aplica al escritorio.

Cuando KineWall se utiliza en KScreenLocker, la reproducción también se pausa mientras la pantalla está apagada y continúa desde la misma posición cuando la pantalla vuelve a encenderse. Esta pausa por estado de la pantalla solo se aplica a KScreenLocker y no cambia el comportamiento del fondo del escritorio.

## Compatibilidad objetivo

- Debian 13 (Trixie)
- KDE Plasma 6.3.x
- Qt 6.8.x
- Qt Multimedia QML
- Fondo de Plasma Desktop
- Fondo de la pantalla de bloqueo de Plasma (KScreenLocker)

## Instalar con `install.sh` — recomendado

Clona o extrae el proyecto, abre una terminal en la raíz del proyecto y ejecuta:

```bash
chmod +x install.sh
./install.sh
```

El instalador:

1. verifica que existan `com.eaangrino.kinewall/` y su `metadata.json`;
2. comprueba los paquetes QML requeridos en Debian;
3. instala con APT las dependencias faltantes únicamente cuando sea necesario;
4. instala KineWall con `kpackagetool6`, o lo actualiza si ya está instalado;
5. verifica que Plasma detecte `com.eaangrino.kinewall`.

El plugin se instala únicamente para el usuario actual. `sudo` solo se utiliza si faltan dependencias de Debian.

La instalación del usuario queda ubicada en:

```text
~/.local/share/plasma/wallpapers/com.eaangrino.kinewall/
```

## Dependencias

En Debian 13 se requieren estos paquetes:

```bash
sudo apt update
sudo apt install qml6-module-qtmultimedia qml6-module-qtquick-dialogs
```

El script de instalación los instala automáticamente si hacen falta.

## Instalación manual

Instala el paquete usando la herramienta KPackage de KDE:

```bash
kpackagetool6 --type=Plasma/Wallpaper --install ./com.eaangrino.kinewall
```

Si KineWall ya está instalado y quieres actualizarlo:

```bash
kpackagetool6 --type=Plasma/Wallpaper --upgrade ./com.eaangrino.kinewall
```

Verifica que Plasma lo detecte:

```bash
kpackagetool6 --type=Plasma/Wallpaper --list | grep -F 'com.eaangrino.kinewall'
```

También puedes comprobar directamente el paquete instalado:

```bash
test -f ~/.local/share/plasma/wallpapers/com.eaangrino.kinewall/metadata.json && echo OK
```

## Uso

### Escritorio

1. Haz clic derecho sobre el escritorio.
2. Selecciona **Configurar escritorio y fondo de pantalla**.
3. En **Tipo de fondo de pantalla**, selecciona **KineWall**.
4. Pulsa **Examinar…** y selecciona un archivo de video.
5. Escoge el modo de posicionamiento.
6. Activa o desactiva, si quieres, **Pausar cuando haya una ventana maximizada**.
7. Aplica los cambios.

### Pantalla de bloqueo (KScreenLocker)

1. Abre **Preferencias del sistema**.
2. Ve a **Seguridad y privacidad → Bloqueo de pantalla**.
3. Abre **Configurar apariencia…**.
4. En **Tipo de fondo de pantalla**, selecciona **KineWall**.
5. Pulsa **Examinar…** y selecciona un archivo de video.
6. Escoge el modo de posicionamiento y aplica los cambios.
7. Pulsa **Meta + L** para probar la pantalla de bloqueo.

El escritorio y la pantalla de bloqueo mantienen su propia configuración de fondo, por lo que pueden utilizar el mismo video o videos diferentes.

La opción **Pausar cuando haya una ventana maximizada** solo afecta al escritorio. KScreenLocker ignora las ventanas maximizadas, pero pausa el video mientras la pantalla está apagada y continúa desde la misma posición cuando vuelve a encenderse.

## Recargar Plasma si es necesario

Si KineWall no aparece inmediatamente después de instalarlo o actualizarlo:

```bash
systemctl --user restart plasma-plasmashell.service
```

Si tu sesión no dispone de esta unidad de systemd de usuario, cierra sesión y vuelve a iniciar sesión.

## Audio

KineWall no crea un `AudioOutput` y configura explícitamente:

```qml
activeAudioTrack: -1
```

Por tanto, la pista de audio queda deshabilitada en lugar de simplemente reproducirse con volumen cero.

## Pausa cuando una ventana está maximizada

KineWall puede pausar opcionalmente la reproducción cuando existe una ventana maximizada y no minimizada en el mismo monitor mientras se utiliza como fondo del escritorio.

La detección utiliza `org.kde.taskmanager` de Plasma y filtra por:

- el escritorio virtual actual;
- la actividad actual;
- el monitor donde se ejecuta la instancia actual de KineWall;
- ventanas no minimizadas;
- ventanas maximizadas.

Cuando se detecta una ventana de ese tipo, KineWall llama a `MediaPlayer.pause()`, conservando la posición de reproducción.

Cuando deja de existir una ventana maximizada que coincida con esos criterios, KineWall llama a `MediaPlayer.play()` y el video continúa desde la misma posición.

Este comportamiento está deshabilitado dentro de KScreenLocker para que las ventanas maximizadas no pausen el video de la pantalla de bloqueo.

La opción está activada por defecto y puede desactivarse desde la configuración de KineWall.

## Pausa mientras la pantalla de bloqueo está apagada

Cuando KineWall se ejecuta dentro de KScreenLocker, pausa `MediaPlayer` si la ventana de Qt Quick deja de presentar frames después de que la pantalla se apaga. `MediaPlayer.pause()` conserva la posición actual.

KineWall mantiene una sonda ligera de presentación mientras está pausado. Cuando la pantalla vuelve a encenderse y la ventana de bloqueo vuelve a presentar un frame, la reproducción continúa desde la posición conservada.

Este comportamiento está limitado a KScreenLocker. El fondo del escritorio no se pausa únicamente porque cambie el estado de la sonda de energía de la pantalla.

## Licencia

MIT
