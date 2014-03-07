package net.jeeeyul.eclipse.themes.preference

import java.io.File
import java.util.ArrayList
import java.util.HashMap
import java.util.List
import java.util.Map
import java.util.Properties
import net.jeeeyul.eclipse.themes.JThemesCore
import net.jeeeyul.eclipse.themes.SharedImages
import net.jeeeyul.eclipse.themes.css.RewriteCustomTheme
import net.jeeeyul.eclipse.themes.preference.actions.AddUserPresetAction
import net.jeeeyul.eclipse.themes.preference.actions.ContributedPresetItems
import net.jeeeyul.eclipse.themes.preference.actions.UserPresetItems
import net.jeeeyul.eclipse.themes.preference.internal.ClosePrevent
import net.jeeeyul.eclipse.themes.preference.internal.DonationPanel
import net.jeeeyul.eclipse.themes.preference.internal.JTPUtil
import net.jeeeyul.eclipse.themes.preference.internal.PreperencePageHelper
import net.jeeeyul.eclipse.themes.preference.preset.IJTPresetManager
import net.jeeeyul.eclipse.themes.rendering.JeeeyulsTabRenderer
import net.jeeeyul.swtend.SWTExtensions
import org.eclipse.core.runtime.Platform
import org.eclipse.jface.action.MenuManager
import org.eclipse.jface.preference.PreferenceDialog
import org.eclipse.jface.preference.PreferenceManager
import org.eclipse.jface.preference.PreferenceNode
import org.eclipse.jface.preference.PreferencePage
import org.eclipse.jface.preference.PreferenceStore
import org.eclipse.swt.SWT
import org.eclipse.swt.custom.CTabFolder
import org.eclipse.swt.widgets.Composite
import org.eclipse.swt.widgets.ToolItem
import org.eclipse.ui.IWorkbench
import org.eclipse.ui.IWorkbenchPreferencePage
import org.eclipse.ui.progress.UIJob
import net.jeeeyul.eclipse.themes.preference.actions.ManagePresetAction

class JTPreperencePage extends PreferencePage implements IWorkbenchPreferencePage {
	extension SWTExtensions swtExt = SWTExtensions.INSTANCE
	Map<AbstractJTPreferencePage, PreperencePageHelper> helperMap = new HashMap
	Composite rootView
	JeeeyulsTabRenderer renderer
	CTabFolder folder
	List<AbstractJTPreferencePage> pages = new ArrayList()

	MenuManager menuManager

	UIJob updatePreviewJob = newUIJob[
		doUpdatePreview()
	]

	new() {
		title = "Jeeeyul's Theme"
		pages += new GeneralPage
		pages += new PartStacksPage
		pages += new OthersPage
		pages += new UserCSSPage

		if(!Platform.running || Platform.inDebugMode || Platform.inDevelopmentMode) {
			pages += new DebugPage
		}
	}

	override init(IWorkbench workbench) {
		this.preferenceStore = JThemesCore.^default.preferenceStore
	}

	override public createContents(Composite parent) {
		for (e : pages) {
			e.init(e.helper)
		}

		rootView = parent.newComposite [
			layout = newGridLayout[]
			folder = newCTabFolder(SWT.CLOSE)[]
			folder => [
				layoutData = FILL_HORIZONTAL[
					widthHint = 450
				]
				setUnselectedCloseVisible(false)
				maximizeVisible = true
				minimizeVisible = true
				addCTabFolder2Listener(new ClosePrevent)
				it.renderer = renderer = new JeeeyulsTabRenderer(it) => [
					debug = false
				]
				for (each : pages) {
					newCTabItem[
						it.text = each.name
						it.image = each.image
						it.control = each.createContents(folder, swtExt, each.helper)
						it.control.background = COLOR_WHITE;
						(it.control as Composite).backgroundMode = SWT.INHERIT_FORCE
						it.data = each
					]
				}
				folder.selection = folder.items.head
				onSelection = [
					updatePreview()
				]
			]
			new DonationPanel(it) => [
				control.layoutData = FILL_HORIZONTAL
			]
		]

		folder.topRight = folder.newToolBar [
			newToolItem(SWT.DROP_DOWN) [
				image = SharedImages.getImage(SharedImages.JTHEME)
				onSelection = [
					menuManager.updateAll(true)
					var item = widget as ToolItem
					var m = menuManager.menu
					m.location = item.parent.toDisplay(item.bounds.bottomLeft.getTranslated(0, 2))
					m.visible = true
				]
			]
		]
		menuManager = new MenuManager()
		menuManager.createContextMenu(folder)

		createActions()

		doLoad()
		doUpdatePreview()

		return rootView
	}

	private def createActions() {
		menuManager => [
			add(
				new MenuManager("Preset") => [
					add(new ContributedPresetItems(this))
				])
			if(presetManager != null) {
				add(
					new MenuManager("User Preset") => [
						add(new AddUserPresetAction(this))
						add(new ManagePresetAction(this))
						add(new UserPresetItems(this))
					])
			}
		]
	}

	private def doLoad() {
		loadFrom(preferenceStore)
	}

	override performOk() {
		saveTo(preferenceStore)
		preferenceStore.save()
		if(Platform.running)
			new RewriteCustomTheme().rewrite()

		return true
	}

	public def void saveTo(JThemePreferenceStore store) {
		pages.forEach[it.save(store, swtExt, helper)]
	}

	public def void loadFrom(JThemePreferenceStore store) {
		for (each : pages) {
			each.load(store, swtExt, each.helper)
		}
		updatePreview()
	}

	override protected performDefaults() {
		var dummy = new JThemePreferenceStore(new PreferenceStore())
		for (e : JTPUtil.listPreferenceKeys) {
			dummy.setValue(e, preferenceStore.getDefaultString(e))
		}

		for (e : pages) {
			e.load(dummy, swtExt, e.helper)
		}

		updatePreview()
	}

	override JThemePreferenceStore getPreferenceStore() {
		super.preferenceStore as JThemePreferenceStore
	}

	def AbstractJTPreferencePage getActivePage() {
		folder.selection.data as AbstractJTPreferencePage
	}

	def private void updatePreview(AbstractJTPreferencePage page) {
		page.updatePreview(folder, renderer.settings, swtExt, page.helper)
	}

	def static void main(String[] args) {
		var manager = new PreferenceManager()
		var prefPage = new JTPreperencePage
		manager.addToRoot(new PreferenceNode("Active", prefPage))
		var userDir = System.getProperty("user.home");
		var file = new File(userDir, ".jet-dummy-pref");
		var store = new PreferenceStore(file.getAbsolutePath());
		var defaults = new Properties
		defaults.load(typeof(JTPreperencePage).getResourceAsStream("default.epf"))
		for (each : defaults.keySet) {
			store.setDefault(each as String, defaults.getProperty(each as String))
		}
		try {
			store.load()
		} catch(Exception e) {
		}
		prefPage.setPreferenceStore(new JThemePreferenceStore(store))
		new PreferenceDialog(null, manager).open

	}

	def void updatePreview() {
		updatePreviewJob.schedule()
	}

	def void doUpdatePreview() {
		for (p : pages) {
			p.updatePreview()
		}
		rootView.layout(true, true)
	}

	override dispose() {
		pages.forEach[it.dispose(swtExt, helper)]
		super.dispose()
	}

	private def getHelper(AbstractJTPreferencePage page) {
		var result = helperMap.get(page)
		if(result == null) {
			result = new PreperencePageHelper(this, page)
			helperMap.put(page, result)
		}
		return result
	}

	def CTabFolder getFolder() {
		return this.folder
	}

	def IJTPresetManager getPresetManager() {
		if(Platform.running)
			return JThemesCore.^default.presetManager
		else
			null
	}
}
