#!/usr/bin/env python3
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Adw, GLib, Gdk
import subprocess, threading, json, re, os, tempfile
from collections import defaultdict

CONFIG_FILE = "/etc/nixos/nexus/user-packages.nix"


def read_packages():
    try:
        with open(CONFIG_FILE) as f:
            content = f.read()
        m = re.search(r'\[([^\[\]]*)\]', content, re.DOTALL)
        if m:
            result = []
            for line in m.group(1).splitlines():
                tok = line.split('#')[0].strip()
                if tok and re.match(r'^[a-zA-Z][a-zA-Z0-9_\-\.]*$', tok):
                    result.append(tok)
            return result
    except Exception:
        pass
    return []


def save_packages(pkg_list):
    lines = "# Verwaltete Pakete — nix-manager\n{ pkgs }: with pkgs; [\n"
    for p in sorted(pkg_list):
        lines += f"  {p}\n"
    lines += "]\n"
    try:
        with open(CONFIG_FILE, 'w') as f:
            f.write(lines)
        return True
    except PermissionError:
        with tempfile.NamedTemporaryFile(mode='w', suffix='.nix', delete=False) as tmp:
            tmp.write(lines)
            tp = tmp.name
        try:
            r = subprocess.run(['pkexec', 'cp', tp, CONFIG_FILE])
            return r.returncode == 0
        finally:
            try:
                os.unlink(tp)
            except Exception:
                pass
    return False


def esc(text):
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


class App(Adw.Application):
    def __init__(self):
        super().__init__(application_id='de.fuchs.nixmanager')
        self.connect('activate', self.on_activate)

    def on_activate(self, _):
        MainWin(application=self).present()


class MainWin(Adw.ApplicationWindow):
    def __init__(self, **kw):
        super().__init__(**kw)
        self.set_title('Nix Manager')
        self.set_default_size(980, 680)

        hb = Adw.HeaderBar()
        stack = Adw.ViewStack()
        sw = Adw.ViewSwitcher()
        sw.set_stack(stack)
        sw.set_policy(Adw.ViewSwitcherPolicy.WIDE)
        hb.set_title_widget(sw)

        rb = Gtk.Button(label='Rebuild')
        rb.add_css_class('suggested-action')
        rb.connect('clicked', lambda _: self.do_rebuild())
        hb.pack_end(rb)

        self.installed = InstalledPage(self)
        self.search = SearchPage(self)
        self.editor = EditorPage()
        stack.add_titled_with_icon(
            self.search, 'search', 'Suchen', 'system-search-symbolic')
        stack.add_titled_with_icon(
            self.installed, 'installed', 'Installiert', 'software-installed-symbolic')
        stack.add_titled_with_icon(
            self.editor, 'editor', 'Editor', 'document-edit-symbolic')

        tv = Adw.ToolbarView()
        tv.add_top_bar(hb)
        tv.set_content(stack)
        self.set_content(tv)

    def do_rebuild(self):
        subprocess.Popen([
            'kitty', '--title', 'NixOS Rebuild', '--hold',
            'bash', '-c',
            'git -C /etc/nixos add -A && sudo nixos-rebuild switch --flake /etc/nixos#nexus'
        ])

    def add_pkg(self, name):
        pkgs = read_packages()
        if name not in pkgs:
            pkgs.append(name)
            if save_packages(pkgs):
                self.installed.refresh()

    def rm_pkg(self, name):
        pkgs = read_packages()
        if name in pkgs:
            pkgs.remove(name)
            if save_packages(pkgs):
                self.installed.refresh()


class SearchPage(Gtk.Box):
    def __init__(self, win):
        super().__init__(orientation=Gtk.Orientation.VERTICAL)
        self.win = win

        top = Gtk.Box(spacing=8)
        top.set_margin_top(12)
        top.set_margin_bottom(8)
        top.set_margin_start(12)
        top.set_margin_end(12)

        self.entry = Gtk.SearchEntry()
        self.entry.set_placeholder_text('Paket suchen… (z.B. vlc, krita, blender)')
        self.entry.set_hexpand(True)
        self.entry.connect('activate', self.do_search)

        btn = Gtk.Button(label='Suchen')
        btn.connect('clicked', self.do_search)
        top.append(self.entry)
        top.append(btn)

        self.lbl = Gtk.Label(label='Suchbegriff eingeben und Enter drücken')
        self.lbl.add_css_class('dim-label')
        self.lbl.set_vexpand(True)

        self.lb = Gtk.ListBox()
        self.lb.set_selection_mode(Gtk.SelectionMode.NONE)
        self.lb.add_css_class('boxed-list')
        self.lb.set_margin_start(12)
        self.lb.set_margin_end(12)
        self.lb.set_margin_bottom(12)

        sc = Gtk.ScrolledWindow()
        sc.set_vexpand(True)
        sc.set_child(self.lb)

        self.panel = Gtk.Stack()
        self.panel.set_vexpand(True)
        self.panel.add_named(self.lbl, 'msg')
        self.panel.add_named(sc, 'list')

        self.append(top)
        self.append(self.panel)

    def do_search(self, _=None):
        q = self.entry.get_text().strip()
        if not q:
            return
        self.lbl.set_text('Suche läuft…')
        self.panel.set_visible_child_name('msg')
        threading.Thread(target=self._bg, args=(q,), daemon=True).start()

    def _bg(self, q):
        try:
            r = subprocess.run(
                ['nix', 'search', 'nixpkgs', q, '--json', '--quiet'],
                capture_output=True, text=True, timeout=90
            )
            GLib.idle_add(self._populate, r.stdout)
        except Exception as e:
            GLib.idle_add(self.lbl.set_text, f'Fehler: {e}')

    def _populate(self, raw):
        while c := self.lb.get_first_child():
            self.lb.remove(c)

        try:
            data = json.loads(raw) if raw.strip() else {}
        except Exception:
            self.lbl.set_text('Fehler beim Parsen der Suche')
            self.panel.set_visible_child_name('msg')
            return

        if not data:
            self.lbl.set_text('Keine Ergebnisse gefunden')
            self.panel.set_visible_child_name('msg')
            return

        installed = set(read_packages())
        icon_theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default())

        for key, info in list(data.items())[:100]:
            name = key.split('.')[-1]
            raw_desc = info.get('description') or ''
            version = info.get('version') or ''
            short = esc(raw_desc[:90])
            full = esc(raw_desc)

            # Icon: erst Paketname, dann ohne Bindestriche, sonst generisch
            candidates = [name, name.lower(), name.lower().replace('-', '_')]
            icon_name = next((c for c in candidates if icon_theme.has_icon(c)), 'package-x-generic')
            icon = Gtk.Image.new_from_icon_name(icon_name)
            icon.set_pixel_size(32)

            row = Adw.ExpanderRow()
            row.set_title(esc(name))
            row.set_subtitle(short)
            row.add_prefix(icon)

            if name in installed:
                b = Gtk.Button(label='Entfernen')
                b.add_css_class('destructive-action')
                b.connect('clicked', lambda _, p=name: self.win.rm_pkg(p))
            else:
                b = Gtk.Button(label='Hinzufügen')
                b.add_css_class('suggested-action')
                b.connect('clicked', lambda _, p=name: self.win.add_pkg(p))

            b.set_valign(Gtk.Align.CENTER)
            row.add_suffix(b)

            if full:
                desc_row = Adw.ActionRow()
                desc_row.set_title('Beschreibung')
                desc_row.set_subtitle(full)
                row.add_row(desc_row)

            if version:
                ver_row = Adw.ActionRow()
                ver_row.set_title('Version')
                ver_row.set_subtitle(esc(version))
                row.add_row(ver_row)

            self.lb.append(row)

        self.panel.set_visible_child_name('list')


class InstalledPage(Gtk.Box):
    def __init__(self, win):
        super().__init__(orientation=Gtk.Orientation.VERTICAL)
        self.win = win

        self.lb = Gtk.ListBox()
        self.lb.set_selection_mode(Gtk.SelectionMode.NONE)
        self.lb.add_css_class('boxed-list')
        self.lb.set_margin_top(12)
        self.lb.set_margin_start(12)
        self.lb.set_margin_end(12)
        self.lb.set_margin_bottom(12)

        sc = Gtk.ScrolledWindow()
        sc.set_vexpand(True)
        sc.set_child(self.lb)
        self.append(sc)
        self.refresh()

    def refresh(self):
        while c := self.lb.get_first_child():
            self.lb.remove(c)
        for p in sorted(read_packages()):
            row = Adw.ActionRow()
            row.set_title(p)
            b = Gtk.Button(label='Entfernen')
            b.add_css_class('destructive-action')
            b.set_valign(Gtk.Align.CENTER)
            b.connect('clicked', lambda _, pkg=p: self.win.rm_pkg(pkg))
            row.add_suffix(b)
            self.lb.append(row)


class EditorPage(Gtk.Box):
    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL)
        self._current_file = None
        self._selected_row = None

        # Linke Seite: Dateibaum
        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        left.set_size_request(240, -1)

        left_header = Gtk.Box(spacing=4)
        left_header.set_margin_top(8)
        left_header.set_margin_bottom(6)
        left_header.set_margin_start(10)
        left_header.set_margin_end(8)

        header = Gtk.Label(label='Nix-Dateien')
        header.add_css_class('heading')
        header.set_hexpand(True)
        header.set_halign(Gtk.Align.START)

        new_btn = Gtk.Button()
        new_btn.set_icon_name('document-new-symbolic')
        new_btn.set_tooltip_text('Neue Datei')
        new_btn.add_css_class('flat')
        new_btn.connect('clicked', self._on_new_file)

        left_header.append(header)
        left_header.append(new_btn)

        self.file_list = Gtk.ListBox()
        self.file_list.set_selection_mode(Gtk.SelectionMode.NONE)
        self.file_list.add_css_class('boxed-list')
        self.file_list.set_margin_start(8)
        self.file_list.set_margin_end(8)
        self.file_list.set_margin_bottom(8)

        sc_left = Gtk.ScrolledWindow()
        sc_left.set_vexpand(True)
        sc_left.set_child(self.file_list)

        left.append(left_header)
        left.append(sc_left)

        sep = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)

        # Rechte Seite: Texteditor
        right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        right.set_hexpand(True)

        bar = Gtk.Box(spacing=8)
        bar.set_margin_top(8)
        bar.set_margin_bottom(8)
        bar.set_margin_start(12)
        bar.set_margin_end(12)

        self.file_label = Gtk.Label(label='Keine Datei ausgewählt')
        self.file_label.add_css_class('dim-label')
        self.file_label.set_hexpand(True)
        self.file_label.set_halign(Gtk.Align.START)
        self.file_label.set_ellipsize(3)

        self.save_btn = Gtk.Button(label='Speichern')
        self.save_btn.add_css_class('suggested-action')
        self.save_btn.set_sensitive(False)
        self.save_btn.connect('clicked', self._on_save)

        bar.append(self.file_label)
        bar.append(self.save_btn)

        sep2 = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)

        self.textview = Gtk.TextView()
        self.textview.set_monospace(True)
        self.textview.set_top_margin(8)
        self.textview.set_bottom_margin(8)
        self.textview.set_left_margin(12)
        self.textview.set_right_margin(12)
        self._buf = self.textview.get_buffer()

        sc_right = Gtk.ScrolledWindow()
        sc_right.set_vexpand(True)
        sc_right.set_hexpand(True)
        sc_right.set_child(self.textview)

        right.append(bar)
        right.append(sep2)
        right.append(sc_right)

        self.append(left)
        self.append(sep)
        self.append(right)

        self._load_file_list()

    def _on_new_file(self, _):
        dialog = Adw.AlertDialog()
        dialog.set_heading('Neue Nix-Datei')
        dialog.set_body('Pfad relativ zu /etc/nixos (z.B. nexus/meine-datei.nix)')
        dialog.add_response('cancel', 'Abbrechen')
        dialog.add_response('create', 'Erstellen')
        dialog.set_response_appearance('create', Adw.ResponseAppearance.SUGGESTED)
        dialog.set_default_response('create')
        dialog.set_close_response('cancel')

        entry = Gtk.Entry()
        entry.set_placeholder_text('nexus/meine-datei.nix')
        entry.set_margin_top(8)
        dialog.set_extra_child(entry)

        dialog.connect('response', self._on_new_file_response, entry)
        dialog.present(self.get_root())

    def _on_new_file_response(self, dialog, response, entry):
        if response != 'create':
            return
        rel_path = entry.get_text().strip()
        if not rel_path:
            return
        if not rel_path.endswith('.nix'):
            rel_path += '.nix'
        full_path = f'/etc/nixos/{rel_path}'
        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        template = '{ config, pkgs, ... }:\n{\n}\n'
        try:
            with open(full_path, 'x') as f:
                f.write(template)
        except FileExistsError:
            pass
        except PermissionError:
            with tempfile.NamedTemporaryFile(mode='w', suffix='.nix', delete=False) as tmp:
                tmp.write(template)
                tp = tmp.name
            subprocess.run(['pkexec', 'bash', '-c',
                f'mkdir -p "$(dirname {full_path})" && cp "{tp}" "{full_path}"'])
            try:
                os.unlink(tp)
            except Exception:
                pass
        self._load_file_list()

    def _load_file_list(self):
        while c := self.file_list.get_first_child():
            self.file_list.remove(c)

        try:
            result = subprocess.run(
                ['find', '/etc/nixos', '-name', '*.nix', '-not', '-path', '*/.git/*'],
                capture_output=True, text=True
            )
            files = sorted(result.stdout.strip().splitlines())

            dirs = defaultdict(list)
            for path in files:
                rel = path.replace('/etc/nixos/', '')
                parts = rel.split('/')
                dir_key = '/'.join(parts[:-1]) if len(parts) > 1 else ''
                dirs[dir_key].append(path)

            # Wurzel-Dateien
            if '' in dirs:
                exp = Adw.ExpanderRow()
                exp.set_title('/etc/nixos')
                exp.set_expanded(True)
                for path in dirs['']:
                    self._add_file_row(exp, path)
                self.file_list.append(exp)

            # Unterordner
            for dir_key in sorted(k for k in dirs if k):
                exp = Adw.ExpanderRow()
                exp.set_title(dir_key)
                exp.set_expanded(True)
                for path in dirs[dir_key]:
                    self._add_file_row(exp, path)
                self.file_list.append(exp)

        except Exception as e:
            print(f'Fehler beim Laden der Dateiliste: {e}')

    def _add_file_row(self, expander, path):
        filename = path.split('/')[-1]
        row = Adw.ActionRow()
        row.set_title(filename)
        row.set_activatable(True)
        row._filepath = path
        row.connect('activated', self._on_row_activated)
        expander.add_row(row)

    def _on_row_activated(self, row):
        if self._selected_row:
            self._selected_row.remove_css_class('accent')
        row.add_css_class('accent')
        self._selected_row = row

        path = row._filepath
        try:
            with open(path) as f:
                content = f.read()
            self._buf.set_text(content)
            self._current_file = path
            self.file_label.set_label(path.replace('/etc/nixos/', ''))
            self.save_btn.set_sensitive(True)
        except Exception as e:
            self._buf.set_text(f'Fehler beim Lesen: {e}')
            self.save_btn.set_sensitive(False)

    def _on_save(self, _):
        if not self._current_file:
            return
        start = self._buf.get_start_iter()
        end = self._buf.get_end_iter()
        content = self._buf.get_text(start, end, False)
        try:
            with open(self._current_file, 'w') as f:
                f.write(content)
        except PermissionError:
            with tempfile.NamedTemporaryFile(mode='w', suffix='.nix', delete=False) as tmp:
                tmp.write(content)
                tp = tmp.name
            try:
                subprocess.run(['pkexec', 'cp', tp, self._current_file])
            finally:
                try:
                    os.unlink(tp)
                except Exception:
                    pass


App().run(None)
