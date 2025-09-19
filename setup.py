# -*- coding: utf-8 -*-

import subprocess
import sys
import os
import shutil
import getpass
import webbrowser
import time
import signal
import re
import pwd

REQUIRED_PIP_PACKAGES = [
	("PyQt6", "PyQt6"),
	("dotenv", "python-dotenv"),
	("requests", "requests")
]

REQUIRED_SYSTEM_PACKAGES = [
	"libxcb-cursor0",
	"libxcb-icccm4",
	"libxcb-image0",
	"libxcb-keysyms1",
	"libxcb-randr0",
	"libxcb-render-util0",
	"libxcb-xinerama0"
]

REQUIRED_ZYPPER_PACKAGES = [
	"libxcb-cursor0",
	"libxcb-icccm4",
	"libxcb-image0",
	"libxcb-keysyms1",
	"libxcb-randr0",
	"libxcb-render-util0",
	"libxcb-xinerama0",
	"libgthread-2_0-0"
]

REQUIRED_DNF_PACKAGES = [
	"xcb-util-cursor",
	"xcb-util-wm",
	"xcb-util-image",
	"xcb-util-keysyms",
	"libxcb",
	"xcb-util-renderutil"
]

def check_distro():
	distro = ""
	pm = ""

	# Liste di compatibilità
	supported_distros = ["debian", "linuxmint", "ubuntu", "MX Linux", "ghostbsd", "fedora", "manjaro", "cachys", "oraclelinux", "bluestar", "neon", "centos", "almalinux", "rocky", "sparky", "opensuse-tumbleweed", "opensuse-leap", "puppy"]
	supported_pms = ["apt", "dnf", "pacman", "pkg"]

	# Rilevamento della distribuzione
	if os.path.exists("/etc/mx-version"):
		distro = "MX Linux"
	elif os.path.exists("/etc/os-release"):
		with open("/etc/os-release", "r") as f:
			for line in f:
				if line.startswith("ID="):
					distro = line.split("=")[1].strip().replace('"', '')
					break

	# Rilevamento del gestore pacchetti
	if shutil.which("apt"):
		pm = "apt"
	elif shutil.which("dnf"):
		pm = "dnf"
	elif shutil.which("pacman"):
		pm = "pacman"
	elif shutil.which("zypper"):
		pm = "zypper"
	elif shutil.which("pkg"):
		pm = "pkg"

	is_distro_supported = distro in supported_distros
	is_pm_supported = pm in supported_pms
	
	if distro == "deepin":
		print(f"🚫 Avviso: La distribuzione '{distro}' non è supportata.")
		print("Interruzione dello script.")
		sys.exit()

	# Ipotesi 1 & 2: Distro supportata o entrambi supportati
	if is_distro_supported:
		print(f"✅ Rilevata distribuzione supportata: {distro} | Gestore pacchetti: {pm}")
		return

	# Ipotesi 3: Distro non supportata, ma PM si
	if not is_distro_supported and is_pm_supported:
		print(f"⚠️ Avviso: La distribuzione '{distro}' non è ufficialmente supportata, ma il gestore pacchetti '{pm}' lo è.")
		
		while True:
			choice = input("Vuoi proseguire comunque? (s/n): ").lower()
			if choice == "s":
				print("Proseguimento...")
				return
			elif choice == "n":
				print("Interruzione su richiesta dell'utente.")
				sys.exit()
			else:
				print("Scelta non valida. Inserisci 's' per sì o 'n' per no.")
	
	# Ipotesi 4: Nessuno dei due è supportato
	else:
		print(f"🚫 Avviso: La distribuzione '{distro}' e il gestore pacchetti '{pm}' non sono supportati.")
		print("Interruzione dello script.")
		sys.exit()

def install_system_package(pkg_name):
	if shutil.which("apt"):
		subprocess.run(["sudo", "apt", "update"], check=False)
		subprocess.run(["sudo", "apt", "install", "-y", pkg_name], check=True)
	elif shutil.which("dnf"):
		subprocess.run(["sudo", "dnf", "install", "-y", pkg_name], check=True)
	elif shutil.which("zypper"):
		subprocess.run(["sudo", "zypper", "install", "--no-confirm", pkg_name], check=True)
	elif shutil.which("pacman"):
		# Fix: Use pacman -S --noconfirm for installation
		subprocess.run(["sudo", "pacman", "-S", "--noconfirm", "--needed", pkg_name], check=True)
	else:
		print(f"Gestore pacchetti non supportato. Impossibile installare: {pkg_name}")
		sys.exit(1)

def check_and_run_setup():
	is_windows = os.name == "nt"
	venv_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".venv")

	# Determina il percorso dell'eseguibile python nel venv
	if shutil.which("zypper"):
		# Su OpenSUSE, forza sempre l'uso di python3.12 nel venv
		venv_python = os.path.join(venv_dir, "bin", "python3.12")
	else:
		# Logica originale per gli altri sistemi
		venv_python = os.path.join(venv_dir, "Scripts" if is_windows else "bin", "python.exe" if is_windows else "python3")

	if not is_windows:
		# Aggiorna il gestore pacchetti prima di installare
		if shutil.which("apt"):
			subprocess.run(["sudo", "apt", "update"], check=False)
		elif shutil.which("dnf"):
			subprocess.run(["sudo", "dnf", "check-update"], check=False)
		elif shutil.which("pacman"):
			subprocess.run(["sudo", "pacman", "-Sy", "--noconfirm"], check=False)

		install_required_system_packages()

		if shutil.which("zypper"):
			print("🔄 Creazione ambiente virtuale con Python 3.12...")
			try:
				# Usa python3.12 per creare il venv
				if not os.path.isdir(venv_dir):
					subprocess.run(["python3.12", "-m", "venv", venv_dir], check=True)
					print("✅ Ambiente virtuale creato con Python 3.12.")
			except subprocess.CalledProcessError as e:
				print(f"❌ Errore nella creazione dell'ambiente virtuale: {e}")
				sys.exit(1)
		else:
			# Logica originale per gli altri sistemi
			py_ver = f"{sys.version_info.major}.{sys.version_info.minor}"
			test_venv_path = os.path.join(os.path.dirname(__file__), ".venv_test_check")
			try:
				subprocess.run([sys.executable, "-m", "venv", test_venv_path], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
				shutil.rmtree(test_venv_path, ignore_errors=True)
			except subprocess.CalledProcessError:
				install_system_package(f"python{py_ver}-venv")

			if not os.path.isdir(venv_dir):
				subprocess.run([sys.executable, "-m", "venv", venv_dir], check=True)

	# Assicura che pip sia disponibile e aggiornato
	subprocess.run([venv_python, "-m", "ensurepip", "--upgrade"], check=True)
	subprocess.run([venv_python, "-m", "pip", "install", "--upgrade", "pip"], check=True)

	# Installa i pacchetti pip richiesti
	for mod, pkg in REQUIRED_PIP_PACKAGES:
		try:
			subprocess.run([venv_python, "-c", f"import {mod}"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
		except subprocess.CalledProcessError:
			subprocess.run([venv_python, "-m", "pip", "install", pkg], check=True)

	print("Setup completato. Ambiente virtuale e dipendenze installate.")


def install_required_system_packages():
	# Detect package manager first
	pm = ""
	if shutil.which("apt"):
		pm = "apt"
	elif shutil.which("dnf"):
		pm = "dnf"
	elif shutil.which("pacman"):
		pm = "pacman"
	elif shutil.which("zypper"):
		pm = "zypper"
	else:
		print("Gestore pacchetti non supportato per la verifica dei pacchetti di sistema.")
		return

	if pm == "dnf":
		for pkg in REQUIRED_DNF_PACKAGES:
			try:
				subprocess.run(["rpm", "-q", pkg], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
			except subprocess.CalledProcessError:
				print(f"Installazione pacchetto di sistema mancante: {pkg}")
				install_system_package(pkg)
	elif pm == "zypper":
		print("🔄 Verifica e sblocco di PackageKit...")
		try:
			# Ferma PackageKit se attivo
			subprocess.run(["sudo", "systemctl", "stop", "packagekit.service"], check=True)
			print("✅ PackageKit disattivato.")
		except subprocess.CalledProcessError:
			print("⚠️ Impossibile fermare PackageKit. Potrebbe essere necessario farlo manualmente.")
			sys.exit(1)
		print("🔄 Installazione di Python 3.12 e pip...")
		try:
			# Installa esplicitamente python312 e python312-pip
			subprocess.run(["sudo", "zypper", "install", "--no-confirm", "python312", "python312-pip"], check=True)
			print("✅ Python 3.12 e pip installati.")
		except subprocess.CalledProcessError as e:
			print(f"❌ Errore nell'installazione di Python 3.12: {e}")
			sys.exit(1)

		# Installa i pacchetti zypper richiesti
		for pkg in REQUIRED_ZYPPER_PACKAGES:
			try:
				subprocess.run(["rpm", "-q", pkg], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
			except subprocess.CalledProcessError:
				print(f"Installazione pacchetto di sistema mancante: {pkg}")
				install_system_package(pkg)
	else:
		# Logica per altri sistemi...
		for pkg in REQUIRED_SYSTEM_PACKAGES:
			if pm == "pacman" and pkg.startswith("libxcb-"):
				pkg_to_install = "libxcb"
			else:
				pkg_to_install = pkg
			try:
				if pm == "apt":
					subprocess.run(["dpkg", "-s", pkg], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
				elif pm == "pacman":
					subprocess.run(["pacman", "-Q", pkg_to_install], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
			except subprocess.CalledProcessError:
				print(f"Installazione pacchetto di sistema mancante: {pkg_to_install}")
				install_system_package(pkg_to_install)

def ensure_running_in_venv():
	# Determina il percorso dell'eseguibile python nel venv
	venv_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".venv")
	if shutil.which("zypper"):
		# Su OpenSUSE, il venv è sempre creato con python3.12
		venv_python = os.path.join(venv_dir, "bin", "python3.12")
	else:
		# Logica originale per gli altri sistemi
		venv_python = os.path.join(venv_dir, "Scripts" if os.name == "nt" else "bin", "python.exe" if os.name == "nt" else "python3")

	if os.path.abspath(sys.executable) != os.path.abspath(venv_python):
		print("🔁 Rilancio lo script all'interno del virtualenv con Python 3.12...")
		try:
			subprocess.run([venv_python] + sys.argv, check=True)
			sys.exit(0)
		except FileNotFoundError:
			print(f"❌ Errore: l'eseguibile Python non è stato trovato in {venv_python}. Assicurati che l'ambiente virtuale sia stato creato correttamente.")
			sys.exit(1)

# Avvia setup e rilancio se serve
check_distro()

# Il resto del codice verrà eseguito solo se la distro è compatibile
check_and_run_setup()
ensure_running_in_venv()


from PyQt6.QtWidgets import (QApplication, QWidget, QVBoxLayout, QPushButton,
							QTextEdit, QMessageBox, QHBoxLayout,
							QLabel, QInputDialog, QLineEdit, QTextBrowser,
							QSizePolicy, QListWidget, QListWidgetItem, QFrame, QAbstractItemView)
from PyQt6.QtCore import QThread, pyqtSignal, Qt, QMutex, QObject, QTimer, QProcess
from PyQt6.QtGui import QFont, QTextCursor, QBrush, QColor

# --- PROJECT CONFIGURATION VARIABLE ---
# The project directory is fixed as requested.
PROJECT_DIR = "/var/www/html/laravel-oxylabs-test"
# --- END PROJECT CONFIGURATION VARIABLE ---

class Worker(QThread):
	"""
	Worker thread to run the setup in the background.
	This prevents the user interface from freezing.
	"""
	progress_updated = pyqtSignal(int)
	log_message = pyqtSignal(str, str) # (message, type)
	finished = pyqtSignal(bool)
	step_status_updated = pyqtSignal(int, str) # (step_index, status_type)

	# New signals for interactive user input
	request_input = pyqtSignal(str, str, str) # (title, label, default_value)
	request_password_input = pyqtSignal(str, str) # (title, label)

	mutex = QMutex()

	STEPS = [
		"Risolvo i problemi di blocco del gestore pacchetti...",
		"Aggiornamento pacchetti di sistema...",
		"Installazione di PHP + estensioni...",
		"Installazione di Node.js e NPM...",
		"Installazione di Composer...",
		"Installazione di Git...",
		"Installazione di MySQL Server...",
		"Pulizia pacchetti...",
		"Configurazione del database...",
		"Clonazione progetto Laravel...",
		"Configurazione permessi...",
		"Installazione dipendenze Laravel...",
		"Configurazione finale di Laravel...",
		"Configurazione di Filament...",
		"Configurazione Cron...",
		"Avvio server e coda..."
	]

	def __init__(self, parent=None):
		super().__init__(parent)
		self.sudo_password = None
		self.input_queue = None
		self.authenticated = False
		self.input_result = None
		self.processes = []
		self.is_canceled = False
		self.current_user = os.environ.get("SUDO_USER") or os.environ.get("USER")
		if self.current_user is None:
			self.current_user = "root"  
            
	def run(self):
		"""
		Contains the main logic of the setup script.
		"""
		self.mutex.lock()
		try:
			self.progress_updated.emit(0)
			self.log_message.emit("Avvio del setup...", "info")
			self.log_message.emit("Avvio script multipiattaforme.", "info")
			
			distro, pm = self.detect_system_b()

			step_index = 0

			self.run_step_with_status_update(step_index, self.STEPS[step_index], self.fix_package_manager_lock, pm)
			if self.is_canceled: return
			step_index += 1

			self.run_step_with_status_update(step_index, self.STEPS[step_index], self.update_packages, pm, distro)
			if self.is_canceled: return
			step_index += 1

			self.run_step_with_status_update(step_index, self.STEPS[step_index], self.install_php_and_extensions, pm)
			if self.is_canceled: return
			step_index += 1

			self.run_step_with_status_update(step_index, self.STEPS[step_index], self.install_nodejs, pm)
			if self.is_canceled: return
			step_index += 1

			self.run_step_with_status_update(step_index, self.STEPS[step_index], self.install_composer, pm)
			if self.is_canceled: return
			step_index += 1

			self.run_step_with_status_update(step_index, self.STEPS[step_index], self.install_git, pm)
			if self.is_canceled: return
			step_index += 1

			self.run_step_with_status_update(step_index, self.STEPS[step_index], self.install_mysql, pm, distro)
			if self.is_canceled: return
			step_index += 1

			self.run_step_with_status_update(step_index, self.STEPS[step_index], self.clean_packages, pm)
			if self.is_canceled: return
			step_index += 1

			self.run_step_with_status_update(step_index, self.STEPS[step_index], self.configure_database, pm)
			if self.is_canceled: return
			step_index += 1

			self.run_step_with_status_update(step_index, self.STEPS[step_index], self.clone_project)
			if self.is_canceled: return
			step_index += 1

			self.run_step_with_status_update(step_index, self.STEPS[step_index], self.fix_permissions)
			if self.is_canceled: return
			step_index += 1

			self.run_step_with_status_update(step_index, self.STEPS[step_index], self.install_dependencies)
			if self.is_canceled: return
			step_index += 1

			self.run_step_with_status_update(step_index, self.STEPS[step_index], self.configure_laravel)
			if self.is_canceled: return
			step_index += 1

			self.run_step_with_status_update(step_index, self.STEPS[step_index], self.configure_filament)
			if self.is_canceled: return
			step_index += 1

			self.run_step_with_status_update(step_index, self.STEPS[step_index], self.configure_cron, pm)
			if self.is_canceled: return
			step_index += 1

			self.run_step_with_status_update(step_index, self.STEPS[step_index], self.start_services)

			self.progress_updated.emit(100)
			self.log_message.emit("✅ Setup completato!", "success")
			self.finished.emit(True)

		except Exception as e:
			self.log_message.emit(f"❌ Errore critico durante il setup: {e}", "error")
			self.finished.emit(False)
			# Update the last active step to error status
			self.step_status_updated.emit(step_index, "error")
		finally:
			self.mutex.unlock()

	def kill_processes(self):
		"""
		Terminate all background processes started by this worker.
		"""
		self.log_message.emit("Terminazione dei processi in background...", "warning")
		for proc in self.processes:
			try:
				if proc.poll() is None:
					# Check if the process is still running
					os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
					self.log_message.emit(f"Processo {proc.pid} terminato.", "warning")
			except OSError as e:
				self.log_message.emit(f"Impossibile terminare il processo: {e}", "error")
		self.processes = []

	def cancel(self):
		self.is_canceled = True

	def set_sudo_password(self, password):
		self.sudo_password = password

	def get_user_input(self, title, label, default_value=""):
		"""
		Requests user input from the main GUI thread.
		This is a blocking call within the worker thread.
		"""
		self.input_result = None
		self.request_input.emit(title, label, default_value)
		# Wait for the main thread to provide the result
		while self.input_result is None:
			QThread.msleep(100) # Wait a bit to avoid busy looping
		result, ok = self.input_result
		if not ok:
			raise Exception("Input dialog canceled by user.")
		return result

	def get_password_input(self, title, label):
		"""
		Requests a password input from the main GUI thread.
		This is a blocking call within the worker thread.
		"""
		self.input_result = None
		self.request_password_input.emit(title, label)
		# Wait for the main thread to provide the result
		while self.input_result is None:
			QThread.msleep(100)
		result, ok = self.input_result
		if not ok:
			raise Exception("Password dialog canceled by user.")
		return result

	def run_command(self, cmd, success_msg="", error_msg="", use_sudo=True, retries=1, delay=5):
		"""
		Executes a system command and handles output and errors.
		Now it manages the sudo password and real-time output.
		"""
		if self.is_canceled: return

		full_cmd = f"/usr/bin/sudo -S {cmd}" if use_sudo else cmd

		for i in range(retries):
			try:
				self.log_message.emit(f"Esecuzione: {full_cmd} (Tentativo {i+1}/{retries})", "realtime")
				process = subprocess.Popen(full_cmd, shell=True, text=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, executable="/bin/bash")

				if use_sudo and self.sudo_password:
					if not self.authenticated:
						self.log_message.emit("Autenticazione sudo in corso...", "info")
					process.stdin.write(self.sudo_password + '\n')
					process.stdin.flush()

				for line in iter(process.stdout.readline, ''):
					if self.is_canceled:
						process.terminate()
						raise Exception("Process canceled by user")
					self.log_message.emit(line.strip(), "output")
					if "incorrect password" in line.lower():
						raise ValueError("Incorrect sudo password provided.")
					if "password for" in line.lower() and use_sudo:
						self.authenticated = True

				process.stdout.close()
				return_code = process.wait()

				if return_code == 0:
					if success_msg:
						self.log_message.emit(success_msg, "success")
					return True
				else:
					self.log_message.emit(f"{error_msg}\nComando fallito con stato di uscita {return_code}", "error")
					# La riga seguente è stata rimossa, in quanto causava l'errore "I/O operation on closed file".
					# La gestione degli errori di rete è già inclusa nel blocco `except Exception as e`.
					return False # Fail immediately for non-network errors

			except ValueError as ve:
				self.log_message.emit(f"❌ Errore di autenticazione: {ve}", "error")
				raise
			except Exception as e:
				full_error = f"Comando fallito: {cmd}\nErrore: {e}" if error_msg else f"Comando fallito: {cmd}\nErrore: {e}"
				self.log_message.emit(full_error, "error")
				if "ECONNRESET" in str(e).lower() or "network" in str(e).lower():
					self.log_message.emit(f"Errore di rete rilevato. Riprovo in {delay} secondi...", "warning")
					time.sleep(delay)
					delay *= 2
				else:
					raise

		self.log_message.emit(f"❌ Comando fallito dopo {retries} tentativi.", "error")
		return False

	def run_as_user(self, cmd, success_msg="", error_msg="", ignore_error=False, interactive=False, retries=1, delay=5):
		"""
		Executes a command without sudo, with optional retries.

		If run as root, it will switch to a non-root user.
		"""
		if self.is_canceled: return

		# If the script is running as root, switch to the user that initiated the sudo command
		if os.getuid() == 0 and self.current_user != "root":
			full_cmd = f"sudo -u {self.current_user} bash -c '{cmd}'"
		else:
			full_cmd = f"bash -c '{cmd}'"

		for i in range(retries):
			try:
				self.log_message.emit(f"Esecuzione: {full_cmd} (Tentativo {i+1}/{retries})", "realtime")
				stdin_pipe = subprocess.PIPE if interactive else None
				process = subprocess.Popen(full_cmd, shell=True, text=True, stdin=stdin_pipe, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

				if interactive and self.input_queue:
					for line in self.input_queue:
						process.stdin.write(line + '\n')
					process.stdin.flush()
					process.stdin.close()

				for line in iter(process.stdout.readline, ''):
					if self.is_canceled:
						process.terminate()
						raise Exception("Process canceled by user")
					self.log_message.emit(line.strip(), "output")

				process.stdout.close()
				return_code = process.wait()

				if return_code != 0 and not ignore_error:
					full_error = f"{error_msg}\nComando fallito con stato di uscita {return_code}" if error_msg else f"Comando fallito: {cmd}"
					self.log_message.emit(full_error, "error")
					raise subprocess.CalledProcessError(return_code, cmd)

				if success_msg:
					self.log_message.emit(success_msg, "success")
				return ""
			except Exception as e:
				if not ignore_error:
					full_error = f"Comando fallito: {cmd}\nErrore: {e}" if error_msg else f"Comando fallito: {cmd}\nErrore: {e}"
					self.log_message.emit(full_error, "error")
					if "ECONNRESET" in str(e).lower() or "network" in str(e).lower():
						self.log_message.emit(f"Errore di rete rilevato. Riprovo in {delay} secondi...", "warning")
						time.sleep(delay)
						delay *= 2
					else:
						raise
		self.log_message.emit(f"❌ Comando fallito dopo {retries} tentativi.", "error")
		return False

	def run_step_with_status_update(self, index, msg, func, *args):
		"""
		Runs a single setup step, updating the status list and log.
		"""
		self.step_status_updated.emit(index, "active")
		self.log_message.emit(f"ℹ️ {msg}", "info")

		try:
			func(*args)
			if not self.is_canceled:
				self.log_message.emit("✅ Passaggio completato.", "success")
				self.step_status_updated.emit(index, "success")
			else:
				self.step_status_updated.emit(index, "canceled")
		except Exception as e:
			self.log_message.emit(f"❌ Errore durante il passaggio: {msg}\nErrore: {e}", "error")
			self.step_status_updated.emit(index, "error")
			# Re-raise the exception to stop the process
			raise

	def detect_system_b(self,):
		"""
		Detects the distribution and package manager.
		"""
		distro = ""
		pm = ""

		if os.path.exists("/etc/mx-version"):
			distro = "MX Linux"
		elif os.path.exists("/etc/os-release"):
			with open("/etc/os-release", "r") as f:
				for line in f:
					if line.startswith("ID="):
						distro = line.split("=")[1].strip().replace('"', '')
						break

		if shutil.which("apt"):
			pm = "apt"
		elif shutil.which("dnf"):
			pm = "dnf"
		elif shutil.which("pacman"):
			pm = "pacman"
		elif shutil.which("zypper"):
			pm = "zypper"
		elif shutil.which("pkg"):
			pm = "pkg"		
			
		return distro, pm

	def fix_package_manager_lock(self, pm):
		"""
		Resolves package manager lock issues.
		"""
		if self.is_canceled: return
		if pm == "apt":
			self.run_command("rm -f /var/lib/dpkg/lock-frontend", "dpkg lock removed.")
			self.run_command("rm -f /var/lib/dpkg/lock", "dpkg lock removed.")
			self.run_command("rm -f /var/cache/apt/archives/lock", "apt lock removed.")
			self.run_command("dpkg --configure -a", "dpkg configured.")
		elif pm == "zypper":
			self.run_command("rm -f /var/lib/rpm/.rpm.lock", "RPM lock removed.")
			self.run_command("rpm --rebuilddb", "RPM database rebuilt.")
			self.run_command("zypper clean --all", "Zypper cache cleaned.")
		elif pm == "dnf":
			self.run_command("dnf clean all", "dnf cache cleaned.")
		elif pm == "pacman":
			self.run_command("rm -f /var/lib/pacman/db.lck", "pacman lock removed.")
		elif pm == "pkg":
			self.run_command("rm -f /var/db/pkg/lock", "pkg lock removed.")
			self.run_command("pkg-static -f install -y", "pkg issues resolved.")

	def update_packages(self, pm, distro):
		"""
		Updates system packages.
		"""
		if self.is_canceled: return
		self.fix_package_manager_lock(pm)
		if pm == "apt":
			if distro == "neon":
				self.run_command("apt-get update", "Apt update completed.")
				self.run_command("apt-get upgrade -y", "Packages upgraded.")
			else:
				self.run_command("apt update", "Apt update completed.")
				self.run_command("apt upgrade -y", "Packages upgraded.")
		elif pm == "dnf":
			self.run_command("dnf upgrade --refresh -y", "Packages updated.")
		elif pm == "pacman":
			self.run_command("pacman -Syu --noconfirm --disable-download-timeout", "Packages updated.")
		elif pm == "zypper":
			self.run_command("zypper --non-interactive refresh", "Repository aggiornati.")
			self.run_command("zypper --non-interactive dup", "Pacchetti aggiornati.")
		elif pm == "pkg":
			self.run_command("pkg update -f", "Pkg update completed.")
			self.run_command("pkg upgrade -y", "Packages upgraded.")

	def install_php_and_extensions(self, pm):
		"""
		Installs PHP and necessary extensions.
		"""
		if self.is_canceled:
			return

		self.log_message.emit("Verifica e installazione di PHP e delle estensioni essenziali...", "info")

		if pm == "pacman":
			# Installa PHP e le estensioni richieste con --noconfirm
			# Pacchetto 'php-intl' viene gestito separatamente dopo per la verifica esplicita
			# Pacchetti aggiuntivi: php, php-fpm, php-gd, unzip, curl
			if not self.run_command("pacman -S --noconfirm php php-fpm php-gd unzip curl", "Pacchetti aggiuntivi PHP installati con successo.", "Errore critico durante l'installazione di pacchetti aggiuntivi PHP."):
				self.log_message.emit("❌ Errore critico durante l'installazione dei pacchetti PHP aggiuntivi. Verificare l'output per dettagli.", "error")
				# A questo punto, dato che il pacchetto principale non è stato installato, potremmo voler uscire.
				# sys.exit(1) # Decommenta se vuoi uscire in caso di fallimento di questi pacchetti essenziali

			# Assicurati che php-intl sia installato esplicitamente
			self.log_message.emit("Installazione/verifica php-intl...", "info")

			# Usa pacman -Q per controllare se è già installato. Non richiede sudo.
			try:
				# Usiamo subprocess.run qui perché non ha bisogno di sudo e non vogliamo gestire ritentativi/autenticazione
				subprocess.run(['pacman', '-Q', 'php-intl'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
				self.log_message.emit("php-intl già installato.", "success")
			except subprocess.CalledProcessError:
				self.log_message.emit("Pacchetto php-intl non trovato, installazione in corso...", "info")
				# Usa run_command per installare php-intl, che gestirà sudo e possibili errori
				if not self.run_command("pacman -S --noconfirm php-intl", "php-intl installato con successo.", "Errore critico: Impossibile installare php-intl. Verifica i tuoi repository."):
					self.log_message.emit("❌ Errore critico: Impossibile installare php-intl. Verificare l'output per dettagli.", "error")
					sys.exit(1) # Uscita critica se php-intl non può essere installato

			self.log_message.emit("Verifica e abilitazione estensioni PHP in php.ini...", "info")

			# Trova il percorso del php.ini utilizzato dalla CLI
			PHP_INI_PATH = None
			try:
				# Usiamo subprocess.check_output per ottenere il percorso di php.ini
				php_ini_output = subprocess.check_output(['php', '-i'], text=True)
				match = re.search(r"Loaded Configuration File => (.+)", php_ini_output)
				if match:
					PHP_INI_PATH = match.group(1).strip()
				else:
					raise ValueError("Impossibile trovare il percorso di php.ini.")
			except (subprocess.CalledProcessError, ValueError) as e:
				self.log_message.emit(f"Avviso: Impossibile trovare il file php.ini ({e}). Tentativo di usare il percorso predefinito.", "warning")
				PHP_INI_PATH = "/etc/php/php.ini" # Percorso comune su Arch/Manjaro

			# Assicurati che le estensioni siano abilitate scommentando le righe nel php.ini
			# Nota: run_command ora gestisce automaticamente sudo e non richiede di anteporre "sudo" al comando sed
			if PHP_INI_PATH: # Procedi solo se abbiamo un percorso valido per php.ini
				self.run_command(f'sed -i \'s/^[;]*extension=pdo_mysql\\(.so\\)*$/extension=pdo_mysql.so/\' "{PHP_INI_PATH}"', "", use_sudo=True)
				self.run_command(f'sed -i \'s/^[;]*extension=intl\\(.so\\)*$/extension=intl.so/\' "{PHP_INI_PATH}"', "", use_sudo=True)
				self.run_command(f'sed -i \'s/^[;]*extension=iconv\\(.so\\)*$/extension=iconv.so/\' "{PHP_INI_PATH}"', "", use_sudo=True)
				self.run_command(f'sed -i \'s/^;extension=mysqli.so/extension=mysqli.so/\' "{PHP_INI_PATH}"', "", use_sudo=True)
				self.run_command(f'sed -i \'s/^;extension=xml.so/extension=xml.so/\' "{PHP_INI_PATH}"', "Estensioni PHP essenziali (intl, iconv, mysqli, pdo_mysql, xml) abilitate (se presenti e commentate).", use_sudo=True)
			else:
				self.log_message.emit("❌ Impossibile procedere con l'abilitazione delle estensioni PHP poiché il percorso di php.ini non è stato trovato.", "error")
		elif pm == "pkg":
			self.run_command(
				"pkg install -y php82 php82-phar php82-filter php82-iconv php82-mbstring php82-dom php82-tokenizer php82-pdo php82-pdo_mysql php82-session php82-xml php82-intl php82-xmlreader php82-zip unzip curl",
				"Pacchetti PHP installati."
			)

		elif pm == "dnf":
			self.run_command(
				"dnf install -y php php-cli php-mbstring php-xml php-bcmath php-curl php-zip php-mysqlnd php-intl unzip curl php-dom",
				"Pacchetti PHP installati."
			)
		elif pm == "apt":
			self.run_command(
				"apt install -y php php-cli php-mbstring php-xml php-bcmath php-curl php-zip php-mysqlnd php-intl unzip curl php-dom",
				"Pacchetti PHP installati."
			)
		elif pm == "zypper":
			PHP_VERSION = "8"
			REQUIRED_PKGS = [
			f"php{PHP_VERSION}",
			f"php{PHP_VERSION}-cli",
			f"php{PHP_VERSION}-mbstring",
			f"php{PHP_VERSION}-bcmath",
			f"php{PHP_VERSION}-curl",
			f"php{PHP_VERSION}-zip",
			f"php{PHP_VERSION}-mysql",
			f"php{PHP_VERSION}-intl",
			f"php{PHP_VERSION}-dom",
			f"php{PHP_VERSION}-phar",
			f"php{PHP_VERSION}-fileinfo",  # Aggiunto per openSUSE
			f"php{PHP_VERSION}-xmlwriter",
			f"php{PHP_VERSION}-xmlreader",
			f"php{PHP_VERSION}-tokenizer",
			f"php{PHP_VERSION}-ctype",
			"unzip",
			"curl"
		]

			for pkg in REQUIRED_PKGS:
				result = subprocess.run(["rpm", "-q", pkg], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
				if result.returncode == 0:
					self.log_message.emit(f"✅ {pkg} già installato.", "info")
				else:
					self.log_message.emit(f"📦 Installazione {pkg}...", "info")
					self.run_command(f"zypper install --no-confirm {pkg}", "Pacchetti PHP installati.")
		else:
			self.log_message.emit("❌ Impossibile procedere con l'installazione delle estensioni PHP. Gestore dei comandi non supportato", "error")


	def install_nodejs(self, pm):
		"""
		Installs Node.js and NPM.
		"""
		if self.is_canceled: return
		self.log_message.emit("Verifico la presenza di Node.js e npm...", "info")
		try:
			subprocess.run(['npm', '--version'], check=True, capture_output=True, text=True)
			self.log_message.emit("Node.js e npm sono già installati. Procedo...", "success")
			return
		except (subprocess.CalledProcessError, FileNotFoundError):
			self.log_message.emit("Node.js o npm non trovati, installazione in corso...", "warning")

		if pm == "apt":
			self.run_command("curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -", "NodeSource repository aggiunto.")
			self.run_command("apt-get install -y nodejs", "Node.js e NPM installati.")
		elif pm == "zypper":
			# Per openSUSE, usa il repository ufficiale o installa direttamente
			# Opzione 1: Installa dalla repository standard di openSUSE
			self.run_command("zypper install --no-confirm nodejs npm", "Node.js e NPM installati.")

			# Se nodejs18 non è disponibile, prova con nodejs generico
			# Questo comando fallirà silenziosamente se nodejs18 non esiste, poi proverà nodejs
			try:
				# Verifica se nodejs18 è stato installato correttamente
				subprocess.run(['node', '--version'], check=True, capture_output=True, text=True)
				self.log_message.emit("Node.js installato correttamente.", "success")
			except (subprocess.CalledProcessError, FileNotFoundError):
				self.log_message.emit("Tentativo con nodejs generico...", "info")
				self.run_command("zypper install --no-confirm nodejs npm", "Node.js e NPM installati.")
		elif pm == "dnf":
			self.run_command("curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash - && sudo dnf install -y nodejs --allowerasing", "Node.js v18 installato.")
		elif pm == "pacman":
			# Aggiunto --disable-download-timeout per prevenire errori di timeout di rete
			self.run_command("pacman -S --noconfirm --needed --disable-download-timeout nodejs npm", "Node.js e NPM installati.")
		elif pm == "pkg":
			self.run_command("pkg install -y www/npm-node18", "Node.js e NPM installati.")

	def install_composer(self, pm):
		"""
		Installs Composer.
		"""
		if self.is_canceled: return
		# Check if Composer is already installed
		try:
			subprocess.run(['composer', '--version'], check=True, capture_output=True, text=True)
			self.log_message.emit("Composer è già installato.", "success")
			return
		except (subprocess.CalledProcessError, FileNotFoundError):
			self.log_message.emit("Composer non trovato, installazione in corso...", "info")

		composer_path = None  # Variabile per tracciare dove viene installato composer

		if pm == "dnf":
			# Find the PHP binary
			php_bins = ["php", "php8", "php82", "php81"]
			php_bin = None
			for bin_name in php_bins:
				try:
					subprocess.run(['which', bin_name], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
					php_bin = bin_name
					break
				except subprocess.CalledProcessError:
					continue

			if php_bin is None:
				self.log_message.emit("🚫 PHP non trovato. Impossibile installare Composer.", "error")
				return

			try:
				# Download composer.phar using curl and the detected PHP binary
				curl_process = subprocess.Popen(["curl", "-sS", "https://getcomposer.org/installer"], stdout=subprocess.PIPE, text=True)
				php_process = subprocess.Popen([php_bin], stdin=curl_process.stdout, stdout=subprocess.PIPE, text=True)
				curl_process.stdout.close()

				output, _ = php_process.communicate()
				if php_process.returncode != 0:
					self.log_message.emit("❌ Errore durante l'installazione di Composer.", "error")
					return

				# Move composer.phar to /usr/local/bin/composer
				self.log_message.emit("ℹ️ Spostando il file eseguibile di Composer...", "info")
				subprocess.run(["sudo", "mv", "composer.phar", "/usr/local/bin/composer"], check=True)
				composer_path = "/usr/local/bin/composer"
				self.log_message.emit("✅ Composer installato con successo in /usr/local/bin/composer.", "success")

			except subprocess.CalledProcessError as e:
				self.log_message.emit(f"❌ Errore durante l'installazione di Composer: {e}", "error")
		elif pm == "pacman":
			self.run_command("sudo pacman -S --noconfirm --needed composer", "Composer installed.")
			composer_path = "/usr/bin/composer"    # Su Arch, composer viene installato qui
		elif pm == "pkg":
			self.run_command("sudo pkg install -y composer", "Composer installed.")
			composer_path = "/usr/local/bin/composer"  # FreeBSD
		elif pm == "apt":
			# Questa sezione è per sistemi basati su apt (come Debian/Ubuntu)
			self.run_command("curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer", "Composer installed via script.")
			composer_path = "/usr/local/bin/composer"
		elif pm == "zypper":
			try:
				self.run_command("sudo zypper install --no-confirm php-composer", "Installato pacchetto per Composer dal repository.")
				composer_path = "/usr/bin/composer"
				composer_version_check = subprocess.run([composer_path, "--version"], capture_output=True, text=True, check=False)
				if composer_version_check.returncode == 0:
					match = re.search(r'Composer version (\d+\.\d+\.\d+)', composer_version_check.stdout)
					if match:
						installed_version = match.group(1)
						if installed_version.startswith("2."):
							self.log_message.emit(f"✅ Composer installato (versione {installed_version}) in: {composer_path}", "info")
							return
						else:
							self.log_message.emit(f"⚠️ Composer installato (versione {installed_version}) ma è inferiore alla versione 2.2 richiesta. Procedo con l'installazione manuale.", "warning")
					else:
						self.log_message.emit(f"⚠️ Non è stato possibile determinare la versione di Composer installato ({composer_path}). Procedo con l'installazione manuale.", "warning")
				else:
					self.log_message.emit(f"⚠️ Impossibile eseguire {composer_path} --version. Procedo con l'installazione manuale.", "warning")

			except subprocess.CalledProcessError:
				self.log_message.emit("⚠️ Installazione tramite pacchetto fallita. Provo con lo script ufficiale di Composer...", "error")
				pass

			# Inizio blocco di installazione manuale
			self.log_message.emit("ℹ️ Scaricamento dello script di installazione di Composer...", "info")

			try:
				php_bin = shutil.which("php8") or shutil.which("php")
				if not php_bin:
					self.log_message.emit("🚫 PHP non trovato. Impossibile installare Composer.", "error")
					sys.exit(1)

				# Esegui lo script di installazione con PHP
				subprocess.run([php_bin, '-r', 'copy("https://getcomposer.org/installer", "composer-setup.php");'], check=True)
				subprocess.run([php_bin, 'composer-setup.php'], check=True)
				subprocess.run([php_bin, '-r', 'unlink("composer-setup.php");'], check=True)

				self.run_command("sudo mv composer.phar /usr/local/bin/composer", "Installato Composer tramite script ufficiale.")
				composer_path = "/usr/local/bin/composer"
				self.log_message.emit(f"✅ Composer installato correttamente in: {composer_path}", "info")

			except subprocess.CalledProcessError as e:
				self.log_message.emit(f"🚫 Errore durante l'installazione manuale di Composer: {e}", "error")
				sys.exit(1)
			except Exception as e:
				self.log_message.emit(f"🚫 Si è verificato un errore inaspettato durante l'installazione manuale di Composer: {e}", "error")
				sys.exit(1)

		if composer_path and composer_path == "/usr/local/bin/composer" and os.path.exists(composer_path):
			self.run_command(f'sudo chmod +x {composer_path}', "Composer made executable.")
		elif composer_path and composer_path != "/usr/local/bin/composer":
			self.log_message.emit(f"Composer installato tramite package manager in {composer_path}, non serve renderlo eseguibile.", "info")
		elif composer_path == "/usr/local/bin/composer" and not os.path.exists(composer_path):
			self.log_message.emit("⚠️ Percorso composer non trovato, saltando chmod.", "warning")

	def install_git(self, pm):
		"""
		Installs Git.
		"""
		if self.is_canceled: return
		if pm == "pacman":
			# Fix: Added --noconfirm and --needed flags
			self.run_command(f"pacman -S --noconfirm --needed git", "Git installed.")
		elif pm == "zypper":
			self.run_command("zypper install --no-confirm git", "Git installed.")
		else:
			self.run_command(f"{pm} install -y git", "Git installed.")

	def install_mysql(self, pm, distro):
		"""
		Installs the MySQL/MariaDB server.
		"""
		if self.is_canceled: return
		if pm == "apt":
			self.run_command("apt install -y mariadb-server", "MariaDB installed.")
			if distro == "MX Linux":
				self.run_command("service mariadb start && update-rc.d mysql enable", "MariaDB started.")
			else:
				self.run_command("systemctl enable --now mysql", "MariaDB started.")
		elif pm == "dnf":
			self.run_command("dnf install -y mariadb-server", "MariaDB installed.")
			self.run_command("systemctl enable --now mariadb", "MariaDB started.")
		elif pm == "zypper":
			self.run_command("zypper install --no-confirm mariadb-server", "MariaDB installed.")
			self.run_command("systemctl enable --now mariadb", "MariaDB started.")
		elif pm == "pacman":
			self.run_command("pacman -S --noconfirm --needed mariadb", "MariaDB installed.")
			self.run_command("mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql", "MariaDB database initialized.")
			self.run_command("systemctl enable --now mariadb", "MariaDB started.")
		elif pm == "pkg":
			self.run_command("pkg install -y mariadb118-server-11.8.2_1 mariadb118-client-11.8.2_1", "MariaDB installed.")
			self.run_command("mariadb-install-db --user=mysql --basedir=/usr/local --datadir=/var/db/mysql", "MariaDB database initialized.")
			self.run_command("service mysql-server onestart", "MariaDB started.")
			self.log_message.emit("Waiting for the MariaDB service to create the socket file...", "info")

	def clean_packages(self, pm):
		"""
		Cleans up unnecessary packages.
		"""
		if self.is_canceled: return
		if pm in ["apt", "dnf", "pkg"]:
			self.run_command(f"{pm} autoremove -y", "Packages cleaned.")
		elif pm == "zypper":
			self.log_message.emit("Per Opensuse non serve.", "info")
		elif pm == "pacman":
			try:
				# Esegui il comando per trovare i pacchetti orfani e controlla se restituisce qualcosa
				result = subprocess.run(["pacman", "-Qdtq"], capture_output=True, text=True, check=True)
				if result.stdout.strip():
					self.run_command("pacman -Rns $(pacman -Qdtq) --noconfirm", "Orphan packages removed.")
				else:
					self.log_message.emit("Nessun pacchetto orfano da rimuovere. Passo oltre.", "info")
			except subprocess.CalledProcessError:
				self.log_message.emit("Nessun pacchetto orfano da rimuovere.", "info")
			except Exception as e:
				self.log_message.emit(f"❌ Errore durante la pulizia dei pacchetti orfani: {e}", "error")
		else:
			self.log_message.emit("❌ Impossibile procedere con la rimozione dei pacchetti orfani. Gestore dei comandi non supportato", "error")

	def configure_database(self, pm):
		"""
		Configures the MySQL database.
		"""
		if self.is_canceled: return
		sql_commands = """
		CREATE DATABASE IF NOT EXISTS laravel_oxylabs_test_database DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
		CREATE USER IF NOT EXISTS 'laravel_oxylabs_test_user'@'localhost' IDENTIFIED BY 'kA[Q+LgF-~1C';
		GRANT ALL PRIVILEGES ON laravel_oxylabs_test_database.* TO 'laravel_oxylabs_test_user'@'localhost';
		FLUSH PRIVILEGES;
		"""
		if pm == "pacman":
			self.run_command(f"mariadb <<EOF\n{sql_commands}\nEOF", "Database configured.")
		elif pm == "pkg":
			self.run_command(f"mariadb -S /var/run/mysql/mysql.sock <<EOF\n{sql_commands}\nEOF", "Database configured.")
		else:
			self.run_command(f"mysql <<EOF\n{sql_commands}\nEOF", "Database configured.")

	def clone_project(self):
		"""
		Clones the project from Git. The project folder is created here.
		"""
		if self.is_canceled: return
		parent_dir = os.path.dirname(PROJECT_DIR)
		if not os.path.exists(parent_dir):
			self.run_command(f"mkdir -p {parent_dir}", f"Cartella padre {parent_dir} creata.")

		if os.path.exists(PROJECT_DIR):
			self.run_command(f"rm -rf {PROJECT_DIR}", "Cartella progetto esistente rimossa.")

		self.run_command(f"git clone https://github.com/smal82/laravel-oxylabs-test.git {PROJECT_DIR}", "Progetto clonato.")
		self.run_command(f"rm -f {PROJECT_DIR}/setup.sh {PROJECT_DIR}/setup2.sh", "File di setup rimossi dal progetto.")

		self.run_command(f"bash -c 'cd {PROJECT_DIR} && git config --global --add safe.directory {PROJECT_DIR}'", "Permessi Git configurati.")
		self.log_message.emit("Clonazione completata.", "success")

	def fix_permissions(self):
		if self.is_canceled:
			return

		try:
			current_user = os.environ.get("SUDO_USER") or os.environ.get("USER")

			if shutil.which("zypper"):
				# openSUSE: recupera gruppo reale associato all'utente
				import pwd
				user_info = pwd.getpwnam(current_user)
				user_group_id = user_info.pw_gid
				group_name = subprocess.getoutput(f"getent group {user_group_id} | cut -d: -f1")

				self.log_message.emit(f"🔧 Cambio proprietà di {PROJECT_DIR} a {current_user}:{group_name}", "info")
				self.run_command(
					f"chown -R {current_user}:{group_name} {PROJECT_DIR}",
					"✅ Permessi aggiornati.",
					"❌ Errore nel cambio proprietà."
				)
			else:
				# Altre distro: mantieni comportamento originale
				self.log_message.emit(f"Changing ownership of {PROJECT_DIR} to user {current_user}.", "info")
				self.run_command(
					f"chown -R {current_user}:{current_user} {PROJECT_DIR}",
					"Permessi aggiornati.",
					"Failed to change ownership."
				)

			# Configura git safe.directory
			self.run_as_user(
				f"git config --global --add safe.directory {PROJECT_DIR}",
				"Git safe.directory configurato."
			)

		except OSError:
			self.log_message.emit(
				"Could not determine current user. Skipping ownership change. This may cause issues.",
				"warning"
			)



	def install_dependencies(self):
		self.log_message.emit("🔧 Inizio installazione dipendenze...", "info")

		if not os.path.isdir(PROJECT_DIR):
			self.log_message.emit("❌ Errore: La cartella del progetto non esiste. Impossibile installare le dipendenze.", "error")
			return

		# Fix: crea la cartella vendor se non esiste
		self.run_as_user(f"mkdir -p {PROJECT_DIR}/vendor", "📁 Cartella vendor creata.")

		# Fix: aggiungi safe.directory per evitare errore Git
		self.run_as_user(f"git config --global --add safe.directory {PROJECT_DIR}", "🔐 Git safe.directory configurato.")

		# Composer
		self.run_as_user(f"cd {PROJECT_DIR} && composer install", "✅ Dipendenze Composer installate.")

		# Configura npm per stabilità di rete
		self.run_as_user("npm config set registry https://registry.npmmirror.com", "✅ Registry npm impostato.")
		self.run_as_user("npm config set prefer-online true", "✅ Preferenza online abilitata.")
		self.run_as_user("npm config set fetch-retries 10", "✅ Retry aumentati.")
		self.run_as_user("npm config set fetch-retry-mintimeout 20000", "✅ Timeout minimo impostato.")
		self.run_as_user("npm config set fetch-retry-maxtimeout 120000", "✅ Timeout massimo impostato.")
		self.run_as_user("npm config delete proxy && npm config delete https-proxy", "✅ Proxy disabilitato.")

		# Aggiorna npm se necessario
		#self.run_as_user("npm install -g npm@latest", "✅ npm aggiornato all'ultima versione.")

		# Installazione con retry esteso
		self.run_as_user(f"cd {PROJECT_DIR} && npm install --yes", "✅ Dipendenze NPM installate.", retries=10, delay=10)



	def configure_laravel(self):
		"""
		Performs the final Laravel configuration.
		"""
		if self.is_canceled: return
		project_dir = PROJECT_DIR
		self.run_as_user(f"cd {project_dir} && php artisan config:clear && php artisan route:clear && php artisan view:clear", "Cache di Laravel cancellata.")

		# .env file management
		if not os.path.exists(os.path.join(project_dir, ".env")):
			self.run_as_user(f"cd {project_dir} && cp .env.example .env && php artisan key:generate", ".env creato e chiave generata.")
		else:
			self.log_message.emit(".env file già presente.", "info")

		# Update DB configuration in .env
		self.run_as_user(fr"cd {project_dir} && sed -i '/DB_CONNECTION=/c\DB_CONNECTION=mysql' .env", "Configurazione DB aggiornata.")
		self.run_as_user(fr"cd {project_dir} && sed -i '/DB_HOST=/c\DB_HOST=127.0.0.1' .env", "Host DB aggiornato.")
		self.run_as_user(fr"cd {project_dir} && sed -i '/DB_PORT=/c\DB_PORT=3306' .env", "Porta DB aggiornata.")
		self.run_as_user(fr"cd {project_dir} && sed -i '/DB_DATABASE=/c\DB_DATABASE=laravel_oxylabs_test_database' .env", "Nome DB aggiornato.")
		self.run_as_user(fr"cd {project_dir} && sed -i '/DB_USERNAME=/c\DB_USERNAME=laravel_oxylabs_test_user' .env", "Utente DB aggiornato.")
		self.run_as_user(fr"cd {project_dir} && sed -i '/DB_PASSWORD=/c\DB_PASSWORD=kA[Q+LgF-~1C' .env", "Password DB aggiornata.")

		# Migrations and storage link
		self.run_as_user(f"cd {project_dir} && php artisan migrate --force && php artisan storage:link", "Migrazioni e link di storage eseguiti.")
		self.log_message.emit("Configurazione di Laravel completata.", "success")

		self.run_as_user(f"cd {project_dir} && composer require symfony/dom-crawler --no-interaction", "DomCrawler installato.")
		self.run_as_user(f"cd {project_dir} && php artisan import:products || true", "Tentato importazione prodotti.")

	def configure_filament(self):
		"""
		Installs Filament and creates the admin user, non-interactively.
		"""
		if self.is_canceled:
			return
		project_dir = PROJECT_DIR

		# Now we handle interactive input for the panel ID
		self.log_message.emit("Installazione di Filament in corso...", "info")
		filament_panel_id = self.get_user_input(
			"Configurazione Filament",
			"Inserisci l'ID del pannello Filament:",
			"admin"
		)

		# Imposta le risposte da passare al processo interattivo
		self.input_queue = [filament_panel_id, "no"]
		self.log_message.emit(f"Eseguo: php artisan filament:install --panels", "output")

		# Avvia il comando in modalità interattiva
		self.run_as_user(
			f"cd {project_dir} && php artisan filament:install --panels",
			"Filament installato.",
			interactive=True
		)
		self.input_queue = None	 # reset per sicurezza

		# Piccola pausa per stabilità
		time.sleep(1)

		# Sostituzione file AdminPanelProvider
		self.log_message.emit("Sostituzione di AdminPanelProvider.php...", "info")
		self.run_as_user(
			f"cd {project_dir} && mv app/Providers/Filament/AdminPanelProvider.php app/Providers/Filament/AdminPanelProvider.bak",
			"Backup del file originale creato."
		)
		self.run_as_user(
			f"cd {project_dir} && mv app/Providers/Filament/AdminPanelProvider-1.php app/Providers/Filament/AdminPanelProvider.php",
			"File corretto spostato al suo posto."
		)

		# Composer dump-autoload e optimize
		self.run_as_user(f"cd {project_dir} && composer dump-autoload", "Autoload di Composer aggiornato.")
		self.run_as_user(f"cd {project_dir} && php artisan optimize:clear", "Cache di Laravel ottimizzata e cancellata.")

		# Creazione utente admin
		admin_name = self.get_user_input("Crea Utente Amministratore", "Nome utente per l'amministratore:", "admin")
		admin_email = self.get_user_input("Crea Utente Amministratore", "Email per l'amministratore:", "admin@example.com")
		admin_password = self.get_password_input("Crea Utente Amministratore", "Password per l'amministratore:")

		self.log_message.emit(f"Creazione utente admin: {admin_name}...", "info")
		self.run_as_user(
			f"cd {project_dir} && php artisan make:filament-user --name='{admin_name}' --email='{admin_email}' --password='{admin_password}'",
			"Utente admin creato."
		)

	def configure_cron(self, pm):
		"""
		Configures the cronjob for Laravel on various systems.
		"""
		if self.is_canceled: return

		cron_cmd = f"* * * * * cd {PROJECT_DIR} && /usr/bin/php artisan schedule:run >> /dev/null 2>&1"

		try:
			self.log_message.emit("Controllo e installazione del gestore Cron...", "info")
			if pm == "apt":
				self.run_command("apt-get install -y cron", "Cron installato.")
				self.run_command("systemctl enable --now cron.service", "Servizio Cron abilitato e avviato.")
			elif pm == "dnf":
				self.run_command("dnf install -y cronie", "Cronie installato.")
				self.run_command("systemctl enable --now crond.service", "Servizio Cron abilitato e avviato.")
			elif pm == "pacman":
				self.run_command("pacman -S --noconfirm --needed cronie", "Cronie installato.")
				self.run_command("systemctl enable --now cronie.service", "Servizio Cron abilitato e avviato.")
			elif pm == "pkg":
				self.run_command("pkg install -y cron", "Cron installato.")
				self.run_command("service cron start", "Servizio Cron avviato.")
			elif pm == "zypper":
				self.run_command("sudo zypper install --no-confirm cronie", "Cronie installato.")
				self.run_command("sudo systemctl enable --now cron.service", "Servizio Cron abilitato e avviato.")
			else:
				self.log_message.emit("Non è stato possibile installare il gestore Cron per il tuo sistema.", "warning")

			self.log_message.emit("Aggiungo il cronjob per lo scheduler di Laravel...", "info")

			# Legge il crontab esistente per non sovrascriverlo completamente
			read_proc = subprocess.Popen(['crontab', '-l'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
			crontab_output, _ = read_proc.communicate()

			# Filtra le righe che non contengono il comando da aggiungere
			lines = [line for line in crontab_output.splitlines() if not cron_cmd in line]

			# Aggiunge il nuovo comando cron al crontab
			lines.append(cron_cmd)
			new_crontab_content = "\n".join(lines) + "\n"

			# Scrive il contenuto in un file temporaneo e lo usa per aggiornare il crontab
			temp_file = "/tmp/crontab.tmp"
			with open(temp_file, "w") as f:
				f.write(new_crontab_content)

			self.run_command(f"crontab {temp_file}", "Cron configurato.")

			# Rimuove il file temporaneo
			os.remove(temp_file)

		except Exception as e:
			self.log_message.emit(f"❌ Errore durante la configurazione del Cron: {e}", "error")

		except Exception as e:
			self.log_message.emit(f"❌ Errore nella configurazione di Cron: {e}", "error")
			raise

	def start_services(self):
		"""
		Starts Laravel services in the background.
		NOTE: These commands are executed without waiting for their completion.
		"""
		if self.is_canceled: return
		project_dir = PROJECT_DIR

		# Start the frontend compilation in the background
		frontend_cmd = f"cd {project_dir} && nohup npm run dev > storage/logs/dev.log 2>&1 &"
		self.log_message.emit(f"Avvio compilazione frontend: {frontend_cmd}", "info")
		proc = subprocess.Popen(frontend_cmd, shell=True, preexec_fn=os.setsid, executable="/bin/bash")
		self.processes.append(proc)

		# Start the Laravel development server
		server_cmd = f"cd {project_dir} && nohup php artisan serve --host=127.0.0.1 --port=8000 > storage/logs/serve.log 2>&1 &"
		self.log_message.emit(f"Avvio server Laravel: {server_cmd}", "info")
		proc = subprocess.Popen(server_cmd, shell=True, preexec_fn=os.setsid, executable="/bin/bash")
		self.processes.append(proc)

		# Start the Laravel queue worker
		queue_cmd = f"cd {project_dir} && nohup php artisan queue:work --tries=3 --stop-when-empty > storage/logs/queue.log 2>&1 &"
		self.log_message.emit(f"Avvio coda Laravel: {queue_cmd}", "info")
		proc = subprocess.Popen(queue_cmd, shell=True, preexec_fn=os.setsid, executable="/bin/bash")
		self.processes.append(proc)

		self.log_message.emit("Tutti i servizi sono stati avviati in background.", "success")

class SetupGUI(QWidget):
	"""
	Main class of the graphical interface.
	"""
	def __init__(self):
		super().__init__()
		self.worker = None
		self._is_canceled = False
		self.initUI()
		self._reset_ui_state()

	def initUI(self):
		"""
		Initializes the user interface elements.
		"""
		self.setWindowTitle('Laravel Setup GUI')
		self.setGeometry(100, 100, 1000, 600)
		self.setWindowFlags(self.windowFlags() | Qt.WindowType.WindowStaysOnTopHint)

		main_layout = QHBoxLayout()
		self.setStyleSheet("background-color: #333; color: #f5f5f5;")

		# Sidebar per i passaggi
		sidebar_frame = QFrame()
		sidebar_frame.setFrameShape(QFrame.Shape.StyledPanel)
		sidebar_frame.setStyleSheet("background-color: #2e2e2e; border: 1px solid #555; padding: 10px;")
		sidebar_layout = QVBoxLayout(sidebar_frame)
		sidebar_layout.setAlignment(Qt.AlignmentFlag.AlignTop)

		steps_label = QLabel("Passaggi Setup")
		steps_label.setFont(QFont("Arial", 14, QFont.Weight.Bold))
		steps_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
		steps_label.setStyleSheet("color: #f5f5f5;")
		sidebar_layout.addWidget(steps_label)

		self.step_list = QListWidget()
		self.step_list.setStyleSheet("""
			QListWidget {
				background-color: #2e2e2e;
				color: #f5f5f5;
				border: none;
				outline: none;
			}
			QListWidget::item {
				padding: 5px;
				margin-bottom: 5px;
				border-radius: 5px;
			}
		""")
		self.step_list.setSelectionMode(QListWidget.SelectionMode.NoSelection)
		self.step_list.setSizePolicy(QSizePolicy.Policy.MinimumExpanding, QSizePolicy.Policy.MinimumExpanding)

		# Aggiungi i passaggi alla lista
		for step_text in Worker.STEPS:
			item = QListWidgetItem(step_text)
			self.step_list.addItem(item)

		sidebar_layout.addWidget(self.step_list)
		main_layout.addWidget(sidebar_frame)

		# Layout principale a destra
		right_layout = QVBoxLayout()

		title_label = QLabel("Laravel Setup")
		title_label.setFont(QFont("Arial", 20, QFont.Weight.Bold))
		title_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
		right_layout.addWidget(title_label)

		self.logText = QTextEdit()
		self.logText.setReadOnly(True)
		self.logText.setStyleSheet("""
			background-color: #2e2e2e;
			color: #f5f5f5;
			border: 1px solid #555;
			padding: 5px;
		""")
		right_layout.addWidget(self.logText)

		button_layout = QHBoxLayout()
		button_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

		self.startButton = QPushButton('Avvia Setup')
		self.startButton.setStyleSheet("""
			QPushButton {
				background-color: #5cb85c;
				color: white;
				border: none;
				padding: 10px 20px;
				border-radius: 5px;
			}
			QPushButton:disabled {
				background-color: #4CAF50;
				color: #A0A0A0;
			}
		""")
		self.startButton.clicked.connect(self.start_setup)
		self.startButton.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Minimum)
		self.startButton.setMinimumHeight(40)
		self.startButton.setMinimumWidth(150)

		button_layout.addWidget(self.startButton)
		right_layout.addLayout(button_layout)

		self.url_buttons_container = QHBoxLayout()
		right_layout.addLayout(self.url_buttons_container)

		main_layout.addLayout(right_layout)
		self.setLayout(main_layout)

	def _reset_ui_state(self):
		"""
		Resets the UI elements to their initial state.
		"""
		self.startButton.show() # Assicurati che il pulsante sia visibile all'inizio
		self.startButton.setEnabled(True)

		while self.url_buttons_container.count():
			item = self.url_buttons_container.takeAt(0)
			widget = item.widget()
			if widget:
				widget.deleteLater()

		# Resetta lo stile dei passaggi nella lista
		for i in range(self.step_list.count()):
			item = self.step_list.item(i)
			item.setForeground(QBrush(QColor("#a0a0a0")))
			item.setFont(QFont("Arial", 12, QFont.Weight.Normal))

	def start_setup(self):
		"""
		Starts the setup process.
		"""
		self.logText.clear()
		self._reset_ui_state()

		password, ok = QInputDialog.getText(self, "Password Sudo",
											"Inserisci la tua password di sudo:",
											QLineEdit.EchoMode.Password)

		if not ok or not password:
			self._log_message("Password sudo non fornita. Annullamento.", "error")
			return

		self._is_canceled = False
		self._set_button_state(running=True)
		self.worker = Worker(parent=self)
		self.worker.set_sudo_password(password)

		self.worker.request_input.connect(self._handle_input_request)
		self.worker.request_password_input.connect(self._handle_password_request)

		self.worker.log_message.connect(self._on_log_message_received)
		self.worker.step_status_updated.connect(self._on_step_status_updated)
		self.worker.finished.connect(self._on_setup_finished)
		self.worker.start()

	def _set_button_state(self, running):
		self.startButton.setEnabled(not running)

	def _handle_input_request(self, title, label, default_value):
		"""
		Handles the request for a standard text input from the worker thread.
		"""
		self.setWindowFlags(self.windowFlags() | Qt.WindowType.WindowStaysOnTopHint)
		self.show()
		result, ok = QInputDialog.getText(self, title, label, QLineEdit.EchoMode.Normal, default_value)
		self.worker.input_result = (result, ok)

	def _handle_password_request(self, title, label):
		"""
		Handles the request for a password input from the worker thread.
		"""
		self.setWindowFlags(self.windowFlags() | Qt.WindowType.WindowStaysOnTopHint)
		self.show()
		result, ok = QInputDialog.getText(self, title, label, QLineEdit.EchoMode.Password)
		self.worker.input_result = (result, ok)

	def _on_step_status_updated(self, index, status_type):
		"""
		Updates the style of the step in the list based on its status.
		"""
		if index >= self.step_list.count():
			return

		item = self.step_list.item(index)

		if status_type == "success":
			item.setForeground(QBrush(QColor("#5cb85c"))) # Green
			item.setFont(QFont("Arial", 12, QFont.Weight.Normal))
			item.setText(f"✅ {Worker.STEPS[index]}")
		elif status_type == "active":
			item.setForeground(QBrush(QColor("white")))
			item.setFont(QFont("Arial", 12, QFont.Weight.Bold))
			item.setText(f"➡️ {Worker.STEPS[index]}")
		elif status_type == "error":
			item.setForeground(QBrush(QColor("#d9534f"))) # Red
			item.setFont(QFont("Arial", 12, QFont.Weight.Bold))
			item.setText(f"❌ {Worker.STEPS[index]}")

		self.step_list.scrollToItem(item, QAbstractItemView.ScrollHint.PositionAtCenter)

	def _on_log_message_received(self, message, message_type):
		"""
		Adds a message to the log with formatting depending on the type.
		"""
		self._log_message(message, message_type)

	def _log_message(self, message, message_type):
		"""
		Adds a message to the log with formatting depending on the type.
		"""
		color = "white"
		if message_type == "success":
			color = "#5cb85c"
			message = f"✅ {message}"
		elif message_type == "error":
			color = "#d9534f"
			message = f"❌ {message}"
		elif message_type == "info":
			color = "#5bc0de"
			message = f"ℹ️ {message}"
		elif message_type == "output":
			color = "#f5f5f5"

		self.logText.moveCursor(QTextCursor.MoveOperation.End)
		self.logText.append(f"<span style='color: {color};'>{message}</span>")

	def _on_setup_finished(self, success):
		"""
		Handles the end of the setup, whether it is completed or failed.
		"""
		self._set_button_state(running=False)

		if self._is_canceled:
			self._log_message("Setup annullato dall'utente.", "info")
			QMessageBox.information(self, "Annullato", "Setup di Laravel annullato.")
			return

		if success:
			self.startButton.hide()
			self._log_message("✅ Setup completato. L'applicazione è pronta.", "success")
			self._log_message("", "info")
			self._log_message("Puoi accedere ai seguenti URL:", "info")

			admin_button = QPushButton("🔒 Pannello di Amministrazione")
			admin_button.setStyleSheet("background-color: #3498db; color: white; border: none; padding: 10px; border-radius: 5px;")
			admin_button.clicked.connect(lambda: webbrowser.open("http://127.0.0.1:8000/admin/login"))

			frontend_button = QPushButton("🛒 Frontend")
			frontend_button.setStyleSheet("background-color: #2ecc71; color: white; border: none; padding: 10px; border-radius: 5px;")
			frontend_button.clicked.connect(lambda: webbrowser.open("http://127.0.0.1:8000/view/products"))

			self.url_buttons_container.addWidget(admin_button)
			self.url_buttons_container.addWidget(frontend_button)

			self.logText.moveCursor(QTextCursor.MoveOperation.End)

			QMessageBox.information(self, "Setup Completato", "Setup di Laravel completato con successo!")
		else:
			QMessageBox.critical(self, "Setup Fallito", "Setup di Laravel fallito. Controlla il log per i dettagli.")

if __name__ == '__main__':
	app = QApplication(sys.argv)
	gui = SetupGUI()
	gui.show()
	sys.exit(app.exec())
