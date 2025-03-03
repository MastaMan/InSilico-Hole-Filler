/*  
[INFO] 
NAME=Hole Filler
VERSION=1.0.1
AUTHOR=Vasyl Lukianenko
DEV=https://3dground.net
HELP=
CLIENT=Andriy Pavlyk

[ABOUT]
Script for bulk placement custom objects to holes=

[1.0.0]
* Initial release =

[1.0.1]
*Changed: Resaved template.max for 2024 =

[FILES]
Install.mcr=
Hole_Type_1.png=
template.max=

[SCRIPT]
*/

struct utilsWrapper (
	fn maxVer  = (
		local v = (maxVersion())[1]
		v = 2000 + ((v / 1000) - 2)
		return v
	),
	fn boost = (
		windows.processPostedMessages() 
	),	
	fn formatString s v: #() tag: "$" = (
		for i in 1 to v.count  do (
			local t = v[i] as string
			s = substituteString s (tag + i as string) (t)
		)
		
		return s
	),
	fn trim s tag: " "= (
		return trimLeft (trimRight s tag) tag
	)
)

struct '@' (
	currScript = getThisScriptFileName(),
	name = getFilenameFile currScript,
	pth = getFileNamePath currScript,
	ini = pth +  sysinfo.username + "@" + sysinfo.computername + ".ini",
	--ini = (getThisScriptFileName()) + ".ini",
	sec = name,
	
	fn trim s tag: "" = (
		s as string
		return (trimLeft (trimRight s tag) tag)
	),
	
	fn add k v sec: "" = (
		if (sec == "") do sec = this.sec
		if (v == undefined) do v = ""
		setIniSetting this.ini sec k (v as string)
	),
	
	fn get k sec: "" type: #string = (
		if (sec == "") do sec = this.sec
		
		if (k == "") do return getINISetting this.ini sec
		
		local v = getIniSetting this.ini sec k
		
		case type of (
			#bool_true: return if (v == "true") then true else false
			#bool_false: return if (v == "false") then false else true
			#int: return try (v as integer) catch(0)
		)
		
		return v
	),
	
	fn del k sec: "" = (
		if (sec == "") do sec = this.sec
		delIniSetting ini sec k
	),	
	
	fn delSec s = (
		delIniSetting ini s
	)
)

global '*' = '@'()	


try(closeRolloutFloater floaterHoleFiller) catch()
global floaterHoleFiller = newRolloutFloater "Hole Filler" 300 295

rollout _rMainHoleFiller "Main" category: 1 (
	group "Hole Types (Placement)" (
		button btnHoleType1 "Hole_Typ1_1" width: 48 height: 48 align: #left
	)
	
	group "Testing" (
		button btnTest "Test Loops Selection"
	)
	group "Loops Selection Settings" (
		label lblChamferNormalThresholdCutoff "Normal Threshold Cutoff:" across: 2 align: #left
		spinner spnChamferNormalThresholdCutoff "" fieldWidth: 60 align: #left type: #float range: [0.0, 270.0, 45.0] scale: 1
		
		label lblHoleinVerts "Hole Min. Verts:" across: 2 align: #left
		spinner spnHoleMinVerts "" fieldWidth: 60 align: #left type: #integer range: [4, 999999, 18] scale: 1
		
		label lblHoleMinEdgeLen "Hole Min. Edge Length:" across: 2 align: #left
		spinner spnHoleMinEdgeLen "" fieldWidth: 60 align: #left type: #worldunits range: [0.001, 999999.0, (units.decodeValue "0.1mm")] scale: 0.1
		
		label lblHoleMaxEdgeLen "Hole Max. Edge Length:" across: 2 align: #left
		spinner spnHoleMaxEdgeLen "" fieldWidth: 60 align: #left type: #worldunits range: [0.001, 999999.0, (units.decodeValue "20.0mm")] scale: 0.1			
	)
	
	fn roundToOneDecimal x = (
		local scaled = x * 10.0
		local rounded = if (scaled >= 0) then floor (scaled + 0.5) else ceil (scaled - 0.5)
		return rounded / 10.0
	)

	fn roundPoint3ToOneDecimal v = (
		return [roundToOneDecimal v.x, roundToOneDecimal v.y, roundToOneDecimal v.z]
	)
	
	fn getVertexNormal obj vIndex = (
		local faces = polyOp.getFacesUsingVert obj vIndex as array
		local normal = [0, 0, 0]
		for f in faces do normal += polyOp.getFaceNormal obj f
		return normalize normal
	)
	
	fn getFlatCircularVertexGroups obj = (
		local minEdgeLen = spnHoleMinEdgeLen.value
		local maxEdgeLen = spnHoleMaxEdgeLen.value
		local minVerts = spnHoleMinVerts.value
		local normalThresholdCutoff = spnChamferNormalThresholdCutoff.value
		
		local visited = #{}
		local count = polyOp.getNumVerts obj
		local groups = #()
		
		for i in 1 to count where not visited[i] do (
			local ring = #{i}
			local queue = #(i)
			local sumPos = polyOp.getVert obj i
			local num = 1
			local normals = #(getVertexNormal obj i)
			
			while (queue.count > 0) do (
				local v = queue[1]
				queue = deleteItem queue 1
				local neighbors = polyOp.getEdgesUsingVert obj v
				local connectedVerts = #()
				
				for ii in neighbors do (
					local verts = polyOp.getVertsUsingEdge obj ii as array
					if (verts.count == 2) do (
						local v1 = polyOp.getVert obj verts[1]
						local v2 = polyOp.getVert obj verts[2]
						local edgeLength = distance v1 v2
						
						if (edgeLength >= minEdgeLen and edgeLength <= maxEdgeLen) do (
							append connectedVerts verts[2]
							append connectedVerts verts[1]
						)
					)
				)
				
				for nv in connectedVerts where not visited[nv] do (
					append queue nv
					ring[nv] = true
					visited[nv] = true
					sumPos += polyOp.getVert obj nv
					num += 1
					
					append normals (getVertexNormal obj nv)
				)
			)
			
			if (num >= minVerts) do (
				local avgNormal = [0,0,0]
				local groupNormals = #()
				local groupNormal = [0,0,0]
				for n in normals do avgNormal += n
				avgNormal = normalize avgNormal
			
				local valid = true
				for n in normals do (				
					--print (acos (dot avgNormal (normalize n)))
					
					if (acos (dot avgNormal (normalize n)) > normalThresholdCutoff) then (
						valid = false
						exit
					) else (
						append groupNormals n
					)
				)
				
				for n in groupNormals do groupNormal += n
				
				if (valid) do append groups #(ring, normalize groupNormal)
			)
		)
		
		local allVerts = #{}
		for g in groups do allVerts += g[1]
		polyOp.setVertSelection obj allVerts
		
		return groups
	)

	fn getSelectedObject = (
		local obj = selection[1]
		if (obj == undefined) do (
			messageBox "Please select one object!" title: "Warning!"
			return undefined
		)
		
		if (not isValidNode obj or isDeleted obj or not canConvertTo obj Editable_Poly) do (
			messageBox "Object not convertable to Editazble Poly!" title: "Error!"
			return undefined
		)
		
		return obj
	)
	
	fn testLoopsSelection = (
		local obj = getSelectedObject()
		if (obj == undefined) do return false
		
		convertToPoly obj
		max modify mode
		subObjectLevel = 1
		PolyToolsModeling.Quadrify false false
		
		getFlatCircularVertexGroups obj
		
		subObjectLevel = 1
	)
	
	fn fillHoles n = (
		local q = queryBox ("Do you really want to fill holes with " + n + "?") title: "Confirm?"
		if (not q) do return false
		
		local p = getFilenamePath (getThisScriptFilename())
		local f = p + "template.max"
		local obj = getSelectedObject()
		if (obj == undefined) do return false
		
		clearSelection()
		mergeMAXFile f #select  #useSceneMtlDups  quiet: true
		if (selection[1] == undefined) do return messageBox ("Can't find " + n + " in template.max!") title: "Error!"
		local hole = selection[1]
		
		convertToPoly obj	
		PolyToolsModeling.Quadrify false false
		
		local groups = getFlatCircularVertexGroups obj
		
		if (groups != undefined) do (
			for grp in groups do (
				local ring = grp[1]
				local groupNormal = roundPoint3ToOneDecimal grp[2]
				local center = [0,0,0]
				local cnt = 0
				local v = [0,0,0]
				
				for r in ring do (
					v = polyOp.getVert obj r
					center += v
					cnt += 1
				)
				
				center = center / cnt
				local diameter = (distance v center) * 2.0			
				local holeDiameter = units.decodeValue (getUserProp hole "diameter")
				local scaleFactor = diameter / holeDiameter
				
				local newHole = copy hole
				newHole.wirecolor = yellow
				newHole.scale = [scaleFactor, scaleFactor, scaleFactor]
				
				newHole.dir = groupNormal
				newHole.pos = center
			)
		)
		
		try (delete hole) catch ()
		select obj
		max modify mode
		subObjectLevel = 1
	)

	on _rMainHoleFiller open do (
		local p = getFilenamePath (getThisScriptFilename())
		local t1 = p + "Hole_Type_1.png"
		
		btnHoleType1.images = #(t1, undefined, 1,1,1,1,1)
	)
	
	on btnTest pressed do testLoopsSelection()
	
	on btnHoleType1 pressed do fillHoles "Hole_Type_1"
)

rollout _rAboutHoleFiller "About" category: 999 (
	group "Description" (
		dotNetControl edtDescription "System.Windows.Forms.Textbox" align:#center height: 60
	)
	
	label lblDummy1 ""
	
	label lblName "" 
	label lblVer ""
	label lblClient ""
	
	label lblDummy2 ""
	
	label lblAuthor ""
	hyperlink lblCopy ""  align: #center color: orange
	
	label lblDummy3 ""
	
	timer tmrRestart "" active: false interval: 300
		
	fn downloadFile url dl = (
		deleteFile dl
		w = dotNetObject "System.Net.WebClient"			
		try(
			spm = dotNetClass "System.Net.ServicePointManager"
			spm.SecurityProtocol = spm.SecurityProtocol.TLS12				
			w.DownloadFile (url + "?time=" + timestamp() as string) dl				
		) catch(
			return false
		)
		
		return true
	)
	
	fn bgUpdate = (
		local url = "https://raw.githubusercontent.com/MastaMan/InSilico-Hole-Filler/main/"
		local main = url + "InSilico-Hole-Filler.ms"
		
		local this = getThisScriptFileName()
		local p = getFileNamePath (getThisScriptFileName())
		local dl = this + ".tmp"
		local r = downloadFile main dl
		if(not r or not doesFileExist dl) do return print "Can't download updates!"
		local vn = getIniSetting dl "INFO" "VERSION"
		local vo = getIniSetting this "INFO" "VERSION"
		local additionalFiles = getIniSetting dl "FILES"
		
		if(vn > vo) do (
			deleteFile this
			renameFile dl this
			
			for n in additionalFiles do (
				local s = getIniSetting dl "FILES" n
				if (s == "") do downloadFile (url + n) (p + n)
				if (s == "deleted") do deleteFile (p + n)
			)
			
			tmrRestart.active = true
		)
		
		deleteFile dl
	)
	
	fn updateWorker = (
		m = dotnetobject "CSharpUtilities.SynchronizingBackgroundWorker"
		m.WorkerSupportsCancellation = true 
		m.CancelAsync() 
		dotNet.addEventHandler m "DoWork" bgUpdate
		m.RunWorkerAsync()	
	)
	
	fn getScriptInfo s releaseInfo: "" =  (
		if(releaseInfo != "") do (
			local r = getINISetting s releaseInfo
			return r
		)
		
		local v = getINISetting s "INFO" "VERSION"
		local a = getINISetting s "INFO" "AUTHOR"
		local n = getINISetting s "INFO" "NAME"
		local o = ""
		for i in (getINISetting s "ABOUT") do o += i + "\r\n"
		local d = getINISetting s "INFO" "DEV"
		local h = getINISetting s "INFO" "HELP"
		local c = getINISetting s "INFO" "CLIENT"
		
		struct data (version, author, name, description, developer, client, help, releases)
		
		local r = for i in (getINISetting s) where (i != "ABOUT" and i != "SCRIPT" and i != "COPY") collect i
		
		return (data version: v author: a name: n description: o developer: d client: c help: h releases: r)
	)
	
	on tmrRestart tick do (
		this = getThisScriptFileName()
		try(fileIn this) catch()
		vo = getIniSetting this "INFO" "VERSION"
		m = ("Script updated to version " + vo + "!\n\n\n")
		for c in (getIniSetting this vo) do (
			m += c + "\n"
		)
		
		--messageBox m title: "Success!" beep: false
		print "---UPDATED---"
		print m
		tmrRestart.active = false
	)

	on _rAboutHoleFiller open do (
		edtDescription.MultiLine = true
		edtDescription.WordWrap = true
		edtDescription.ReadOnly = true
		edtDescription.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").FixedSingle
		
		
		local i = getScriptInfo (getThisScriptFilename())
		
		lblName.caption = i.name
		lblAuthor.caption = i.author
		lblVer.caption = i.version
		lblCopy.address = lblCopy.caption = i.developer
		lblClient.caption = i.client
		edtDescription.text = i.description
		
		try (floaterHoleFiller.title = i.name + " " + i.version) catch()
		try (_rMainHoleFiller.title = i.name + " v" +  i.version) catch()
		
		updateWorker()
		
		local x = '*'.get "x"
		local y = '*'.get "y"
		
		if (x != "" and y != "") do (
			x = x as integer
			y = y as integer
			floaterHoleFiller.pos = [x, y] 
		)		
	)
	
	on _rAboutHoleFiller close do (
		local p = floaterHoleFiller.pos
		
		'*'.add "x" p.x
		'*'.add "y" p.y
	)	
)

addRollout _rMainHoleFiller floaterHoleFiller rolledUp: false
addRollout _rAboutHoleFiller floaterHoleFiller rolledUp: true