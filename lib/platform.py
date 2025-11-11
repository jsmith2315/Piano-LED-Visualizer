import os
import subprocess
from lib.log_setup import logger

class Hotspot:
    def __init__(self, hotspot):
        # Stubbed hotspot class (does nothing)
        logger.info("Hotspot module disabled — no Wi-Fi control will be attempted.")

class PlatformBase:
    def __getattr__(self, name):
        def method(*args, **kwargs):
            return False, f"Method '{name}' is not supported on this platform", ""
        return method

class PlatformNull(PlatformBase):
    def __getattr__(self, name):
        return self.pass_func
    def pass_func(self, *args, **kwargs):
        pass

class PlatformRasp(PlatformBase):
    @staticmethod
    def check_and_enable_spi():
        try:
            if not os.path.exists('/dev/spidev0.0'):
                logger.info("SPI not enabled. Attempting to enable SPI...")
                subprocess.run(['sudo', 'raspi-config', 'nonint', 'do_spi', '0'], check=True)
                logger.info("SPI enabled (reboot may be required).")
                return False
            return True
        except Exception as e:
            logger.warning(f"SPI check/enable failed: {e}")
            return False

    @staticmethod
    def disable_system_midi_scripts():
        try:
            service_name = 'midi.service'
            subprocess.call(['sudo', 'systemctl', 'disable', service_name], check=False)
            subprocess.call(['sudo', 'systemctl', 'stop', service_name], check=False)
            logger.info("Disabled MIDI system service (if present).")
        except Exception as e:
            logger.warning(f"Error disabling MIDI scripts: {e}")

    def install_midi2abc(self):
        # Stub — skip auto apt install
        logger.info("Skipping automatic abcmidi installation (handled manually).")

    @staticmethod
    def update_visualizer():
        logger.info("Visualizer auto-update skipped (manual only).")

    @staticmethod
    def shutdown():
        subprocess.call(["sudo", "/sbin/shutdown", "-h", "now"])

    @staticmethod
    def reboot():
        subprocess.call(["sudo", "/sbin/reboot", "now"])

    @staticmethod
    def restart_visualizer():
        subprocess.call(["sudo", "systemctl", "restart", "pianoled"], shell=False)

    # All hotspot and Wi-Fi control methods replaced with harmless stubs
    def create_hotspot_profile(self): pass
    def change_hotspot_password(self, new_password): pass
    def enable_hotspot(self): pass
    def disable_hotspot(self): pass
    def manage_hotspot(self, *args, **kwargs): pass
    def connect_to_wifi(self, *args, **kwargs): pass
    def disconnect_from_wifi(self, *args, **kwargs): pass
    def get_wifi_networks(self): return []
    def is_hotspot_running(self): return False
    def get_current_connections(self): return True, "Stubbed connection", "00:00:00:00:00:00"
    def get_local_address(self): return {"success": True, "local_address": "stub.local", "ip_address": "127.0.0.1"}
    def change_local_address(self, new_name): return True
