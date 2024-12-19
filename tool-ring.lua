-----------------------------------------------------------------
-- Tool Ring for Aseprite
-- Made by apsyll
-- Version : 2
-- Date: 2024-12-10
-- https://community.aseprite.org/t/tool-ring-script/22314
-----------------------------------------------------------------

-- save all position of the main widgets as a part to be loaded as well.
TOOL_RING_LIST = {}
IS_LOADED = false

function init(plugin)
    print("Aseprite is initializing my plugin")
  
    -- we can use "plugin.preferences" as a table with fields for
    -- our plugin (these fields are saved between sessions)
    if plugin.preferences.toolRings == nil then
      plugin.preferences.toolRings = {}
    end
  
    --
    plugin:newCommand{
      id="ToolRingCommand",
      title="Tool Ring",
      group="view_controls",
      onclick=function()
        InitToolRing(plugin.preferences.toolRings)
      end
    }
    -- plugin:newCommand{
    --     id="ToolRingExitCommand",
    --     title="Test Exit",
    --     group="view_controls",
    --     onclick=function()
    --         local toolRings = ExitToolRing()
    --         if toolRings ~= nil then
    --             print('is not nil')
    --             if #toolRings > 0 then
    --                 print('count: '..#toolRings)
    --                 plugin.preferences.toolRings = toolRings
    --             end
    --         end
    --     end
    --   }
  end
  
  function exit(plugin)
    local toolRings = ExitToolRing()
    if toolRings ~= nil then
        if #toolRings > 0 then
            plugin.preferences.toolRings = toolRings
        end
    end
  end

--Set the position where the main dialog should be drawn
local MAIN_DLG_POSITION = Point(800,100)
-- Set the size of the buttons for each tool
local BUTTON_SIZE = 30
--Set the extra space for the dialog sorrounding the buttons
local BORDER_SIZE = 6
--Set the distance the ring should be drawn around the main dialog
local RING_DISTANCE = 40

-- The types of widgets
local CHILD = 0
local ACTION = 1
local MAIN = 2

-- Mouse object to track state
local mouse = {
    position = Point(0, 0),
    leftClick = false,
    rightClick = false,
    buttonPressed = false,
    ev = nil
}

-- Widget class
Widget = {}
Widget.__index = Widget

function Widget:new(name, type, bounds, icon, color, perform)
    local action = perform or {} -- prevent indexing nil
    local widget = {
        name = name,
        type = type or CHILD, -- set standard type to child if none is given
        bounds = bounds,
        icon = icon or nil,
        color = color or nil,
        dialog = nil,
        onLPressed = action.onLPressed or function() end,
        onLReleased = action.onLReleased or function () end,
        onRPressed = action.onRPressed or function() end,
        onRReleased = action.onRReleased or function () end,
        show = false,
        state = "normal",
    }
    setmetatable(widget, self)
    return widget
end

function Widget:createDialog(toolRing)
    local dlg = Dialog{self.name, notitlebar = true}
    dlg:canvas{
        id = "canvas_" .. self.name,
        width = self.bounds.width,
        height = self.bounds.height,
        onpaint = function(ev)
            local ctx = ev.context
            ctx:drawThemeRect("button_" .. self.state, Rectangle(0, 0, self.bounds.width-toolRing.borderSize, self.bounds.height-toolRing.borderSize))
            local border = toolRing.borderSize or BORDER_SIZE
            local width = self.bounds.width - border
            local height = self.bounds.height - border
            if self.icon then
                local center = Point(width / 2, height / 2)
                local size = Rectangle(0, 0, 16, 16)
                ctx:drawThemeImage(self.icon, center.x - size.width / 2, center.y - size.height / 2)
            elseif self.color then
                ctx.antialias = true
                ctx:beginPath()
                ctx.color = self.color
                ctx:roundedRect(Rectangle(border, border, width - border*2, height - border*2), border)
                ctx:closePath()
                ctx:fill()
            end
        end,
        onmouseup = function(ev)
            ev.type = "mouse_up"
            mouse.buttonPressed = false
            mouse.ev = ev
            HandleMouseEvents(ev, self,toolRing)
        end,
        onmousemove = function(ev)
            ev.type = "mouse_move"
            mouse.ev = ev
            HandleMouseEvents(ev, self, toolRing)
        end,
        onmousedown = function(ev)
            ev.type = "mouse_down"
            mouse.buttonPressed = true
            mouse.ev = ev
            HandleMouseEvents(ev, self,toolRing)
        end
    }
    self.dialog = dlg
end

--weird way but it might work..
function Widget:createMainDialog(toolRing)
    local dlg = Dialog{self.name, notitlebar = true}
    dlg:canvas{
        id = "canvas_" .. self.name,
        width = self.bounds.width,
        height = self.bounds.height,
        onpaint = function(ev)
            toolRing:adjustButtonSize()
            local ctx = ev.context
            local border = toolRing.borderSize or BORDER_SIZE
            local width = self.bounds.width - border
            local height = self.bounds.height - border
            ctx:drawThemeRect("button_" .. self.state, Rectangle(0, 0, self.bounds.width - border, self.bounds.height - border))
            if self.color then
                ctx.antialias = true
                ctx:beginPath()
                ctx.color = self.color
                ctx:roundedRect(Rectangle(border/2, border/2, width - border * 1.25, height - border * 1.25), border)
                ctx:closePath()
                ctx:fill()
                ctx.antialias = false
            end
            if self.icon then
                local center = Point(width / 2, height / 2)
                local size = Rectangle(0, 0, 18, 18)
                ctx:drawThemeImage(self.icon, center.x - size.width / 2, center.y - size.height / 2)
            end
            -- add draw pie chart code here
            if toolRing.start_time then
                toolRing:drawPieChart(ctx,self)
            end
        end,
        onmouseup = function(ev)
            ev.type = "mouse_up"
            mouse.buttonPressed = false
            mouse.ev = ev
            HandleMouseEvents(ev, self,toolRing)
        end,
        onmousemove = function(ev)
            ev.type = "mouse_move"
            mouse.ev = ev
            HandleMouseEvents(ev, self, toolRing)
        end,
        onmousedown = function(ev)
            ev.type = "mouse_down"
            mouse.buttonPressed = true
            mouse.ev = ev
            HandleMouseEvents(ev, self,toolRing)
        end
    }
    self.dialog = dlg
end

function Widget:showDialog(toolRing)
    if not self.dialog then
        self:createDialog(toolRing)
    end
    self.dialog:show{ bounds = self.bounds, wait = false }
    self.dialog:repaint()
    self.show = true
end

function Widget:closeDialog()
    if self.dialog then
        self.dialog:close()
        self.show = false
    end
end

function Widget:updateState(state)
    if self.dialog then
        self.state = state
        self.dialog:repaint()
    end
end


-- Mouse and Button Event Handlers
function HandleMouseEvents(ev, widget, ring)
    local button = ev.button
    local mousePosition = Point(ev.x, ev.y)
    ring:updateActiveWidget(mousePosition)
    if ev.type == "mouse_down" then
        if widget.type ~= CHILD then -- child widgets have just on released actions
            if button == MouseButton.LEFT then
                mouse.leftClick = true
                widget:onLPressed(ring)
            elseif button == MouseButton.RIGHT then
                mouse.rightClick = true
                widget:onRPressed(ring)
            end
        end
    elseif ev.type == "mouse_up" then
        if button == MouseButton.LEFT then
            widget:onLReleased(ring)
            mouse.leftClick = false
        elseif button == MouseButton.RIGHT then
            widget:onRReleased(ring)
            mouse.rightClick = false
        end
    elseif ev.type == "mouse_move" then
        mouse.position = mousePosition
    end
end

-- ToolRing class
ToolRing = {}
ToolRing.__index = ToolRing

function ToolRing:new(position, buttonSize, borderSize, ringDistance)
    local ring = {
        position = position or Point(0, 0),
        buttonSize = buttonSize or 30,
        borderSize = borderSize or 6,
        ringDistance = ringDistance or 40,
        widgets = {}, -- all widgets
        childWidgets = {},
        actionWidgetsL ={},
        actionWidgetsR ={},
        mainWidget = nil,
        activeWidget = nil,
        startTime = nil,
        timer = nil
    }
    setmetatable(ring, self)

    -- Initialize the main widget with proper access to self (ring)
    ring.mainWidget = Widget:new(
        "Main Canvas",
        MAIN,
        Rectangle((position or Point(0, 0)).x, (position or Point(0, 0)).y, (buttonSize or 30) + (borderSize or 6), (buttonSize or 30) + (borderSize or 6)),
        "tool_pencil",
        Color{ r=0, g=0, b=0, a=0 },
        {
            onLPressed = function() ring:onLPressed() end,
            onRPressed = function() ring:onRPressed() end,
            onLReleased = function() ring:onLReleased() end,
            onRReleased = function() ring:onRReleased() end
        }
    )
    ring:setUpWidgets()
    return ring
end

function ToolRing:setUpWidgets()
    -- Add default widgets
    self:addToolWidget("pencil")
    self:addToolWidget("eraser")
    self:addColorWidget()
    -- Add left function widgets
    local rec = Rectangle(0, 0, BUTTON_SIZE + BORDER_SIZE, BUTTON_SIZE + BORDER_SIZE)
    local functionAddToolWidget = Widget:new('addTool',ACTION,rec,"tool_"..app.activeTool.id,nil,{onLReleased = function() self:addToolWidget(nil) self:toggleWidgets(false,self.widgets) end})
    self:addWidget(functionAddToolWidget)
    table.insert(self.actionWidgetsL,functionAddToolWidget)
    local functionAddColourWidget =Widget:new('addColour',ACTION,rec, nil, app.fgColor,{onLReleased = function() self:addColorWidget() self:toggleWidgets(false,self.widgets) end})
    self:addWidget(functionAddColourWidget)
    table.insert(self.actionWidgetsL,functionAddColourWidget)
    -- Add right function widgets
    local closeWidget = Widget:new("Close",ACTION,rec,nil,nil,{onRReleased = function () self:close() end})
    self:addWidget(closeWidget)
    table.insert(self.actionWidgetsR,closeWidget)
end

function ToolRing:addWidget(widget)
    table.insert(self.widgets, widget)
    if widget.type == CHILD then
        table.insert(self.childWidgets,widget)        
    end
end

function ToolRing:removeWidget(widget) -- Function to remove widget from a table 
    local function removeFromTable(tbl, w) 
        for i, widget in ipairs(tbl) do 
            if widget == w then 
                table.remove(tbl, i) 
                break 
            end 
        end 
    end 
    -- Close Widget
    widget:closeDialog()
    -- Remove from main widgets table 
    removeFromTable(self.widgets, widget) 
    -- Remove from childWidgets, actionWidgetsL, actionWidgetsR if applicable 
    removeFromTable(self.childWidgets, widget) 
    removeFromTable(self.actionWidgetsL, widget) 
    removeFromTable(self.actionWidgetsR, widget)
end

function ToolRing:toggleWidgets(show,widgets)
    if show then
        self:showWidgets(widgets)
    else
        self:closeWidgets(widgets)
    end
end

function ToolRing:showWidgets(widgets)
    local angle = 0
    local distance = self.ringDistance
    local bounds = self.mainWidget.dialog.bounds
    self.position = Point((bounds.x + bounds.width /2 )- self.borderSize/2, (bounds.y + bounds.height /2) - self.borderSize/2)
    for _, widget in ipairs(widgets) do
        local rad = math.rad(angle)
        local new_x = self.position.x + distance * math.cos(rad)
        local new_y = self.position.y + distance * math.sin(rad)
        widget.bounds.x = new_x - self.buttonSize /2
        widget.bounds.y = new_y - self.buttonSize /2
        widget:showDialog(self)
        angle = angle + (360 / #widgets)
    end
end

function ToolRing:closeWidgets(widgets)
    for _, widget in ipairs(widgets) do
        widget:closeDialog()
    end
end

function ToolRing:showMainWidget()
    self.mainWidget:createMainDialog(self)
    self.mainWidget:showDialog(self)
end

function ToolRing:updateActiveWidget(mousePosition)
    for _, widget in ipairs(self.widgets) do
        if widget.bounds:contains(mousePosition) then
            if self.activeWidget ~= widget then
                if self.activeWidget then
                    self.activeWidget:updateState("normal")
                end
                self.activeWidget = widget
                widget:updateState("hot")
            end
            return
        end
    end
end

-- sets the main widgets icon and color to the app active ones 
function ToolRing:getActiveSet()
    self.mainWidget.icon = "tool_" .. app.activeTool.id
    self.mainWidget.color = app.fgColor
end

-- sets the new button size to the current main dialog size
function ToolRing:adjustButtonSize()
    local newSize = math.max(BUTTON_SIZE,math.min(self.mainWidget.dialog.bounds.width, self.mainWidget.dialog.bounds.height))
    local newDist = (math.floor( (BUTTON_SIZE / RING_DISTANCE) * newSize))
    newDist = math.max(newDist, RING_DISTANCE)
    self.buttonSize = newSize
    self.ringDistance = newDist
    self.position = Point(self.mainWidget.bounds.x,self.mainWidget.bounds.y)
    self.mainWidget.bounds = Rectangle(0,0,newSize,newSize)
    for _, widget in ipairs(self.widgets) do
        widget.bounds = Rectangle(0,0,newSize,newSize)
        end
end

function ToolRing:startPieChart()
    local timer = Timer{
        interval=1/24,
        ontick=function()
            self:animatePieChart()
        end }
    self.start_time = os.time()
    self.percentage = 0.00
    self.mainWidget:updateState("normal")
    timer:start()
    self.timer = timer
end

function ToolRing:stopPieChart()
    self.start_time = nil
    self.percentage = 0.00
    self.timer:stop()
    self:getActiveSet()
    self.mainWidget.dialog:repaint()
end

function ToolRing:animatePieChart()
    local isTimerRunning = self.timer.isRunning
    local start_time = self.start_time
    local timer = self.timer
    if not mouse.buttonPressed then
        timer:stop()
    end
    if isTimerRunning then
        if start_time then
            local elapsed = os.time() - start_time
            local percentage = math.min(1, elapsed / 2)
            if percentage >=1 then
                timer:stop()
            end
            self.mainWidget.dialog:repaint()            
        else
            timer:stop()
        end
    end
end

function ToolRing:drawPieChart(ctx, widget)
    local c = Color{ r=155, g=155, b=155, a=55 }
    ctx.color = c
    local percentage = self.percentage or 0.00
    local center = Point(ctx.width / 2, ctx.height / 2)
    local radius = ctx.width / 2 - 6
    if percentage >= 1 then
        self:stopPieChart()     
        self:onTab2Hold()   
    elseif self.start_time then
        ctx.antialias = true
        ctx:beginPath()
        ctx:moveTo(center.x, center.y)
        for angle = 0, 360 * percentage, 1 do
            local radian = math.rad(angle)
            local x = center.x + radius * math.cos(radian)
            local y = center.y + radius * math.sin(radian)
            ctx:lineTo(x, y)
        end
        ctx:closePath()
        ctx:fill()
        ctx.antialias = false
        self.percentage = percentage + 1 / 24
    end
end

function ToolRing:onLPressed()
    self:startPieChart()
    self:toggleWidgets(mouse.buttonPressed,self.childWidgets)
    self:getActiveSet()
end

function ToolRing:onLReleased()
    self:toggleWidgets(false, self.widgets)
    self:stopPieChart()
end

function ToolRing:onRPressed()
    self:startPieChart()
    self:toggleWidgets(mouse.buttonPressed, self.childWidgets)
    self:getActiveSet()
end

function ToolRing:onRReleased()
    self:toggleWidgets(false, self.widgets)
    self:stopPieChart()
end

function ToolRing:updateNewAPPWidget()
    local widgets = self.actionWidgetsL
    for _, widget in ipairs(widgets) do
        widget.dialog = nil
        if widget.color then
            widget.color = app.fgColor
        elseif widget.icon then
            widget.icon = "tool_"..app.activeTool.id
        end
    end
end

function ToolRing:onTab2Hold()
    if mouse.buttonPressed then
        self:toggleWidgets(false, self.childWidgets)
        if mouse.leftClick then
            self:updateNewAPPWidget()
            self:toggleWidgets(true,self.actionWidgetsL)
        elseif mouse.rightClick then
            self:toggleWidgets(true,self.actionWidgetsR)
        end
    end
end

function ToolRing:addToolWidget(ptool)
    local tool = ptool or app.activeTool.id
    local perform = {} 
    perform.onLReleased = function() 
        app.activeTool = tool 
        self:toggleWidgets(false, self.childWidgets) 
        self:stopPieChart()
    end 
    perform.onRReleased = function(widget) 
        self:removeWidget(widget) 
        self:toggleWidgets(false, self.childWidgets) 
        self:stopPieChart()
    end 
    local widget = Widget:new(tool, CHILD, Rectangle(0, 0, self.buttonSize + self.borderSize, self.buttonSize + self.borderSize), "tool_" .. tool, nil, perform) 
    self:addWidget(widget) 
end

function ToolRing:addColorWidget(pcolor)
    local color = pcolor or app.fgColor
    local perform = {} 
    perform.onLReleased = function() 
        app.fgColor = color 
        self:toggleWidgets(false, self.childWidgets) 
        self:stopPieChart()
    end 
    perform.onRReleased = function(widget) 
        self:removeWidget(widget) 
        self:toggleWidgets(false, self.childWidgets) 
        self:stopPieChart()
    end 
    local widget = Widget:new("Color", CHILD, Rectangle(0, 0, self.buttonSize + self.borderSize, self.buttonSize + self.borderSize), nil, color, perform) 
    self:addWidget(widget) 
end

function ToolRing:close()
    for i, tr in ipairs(TOOL_RING_LIST) do 
        if self == tr then 
            table.remove(TOOL_RING_LIST, i) 
            break 
        end 
    end
    self:closeWidgets(self.widgets)
    self.mainWidget:closeDialog()
end

function ExitToolRing()
    local ringList = {}
    for _, toolRing in ipairs(TOOL_RING_LIST) do
        local rPos = {x = toolRing.mainWidget.dialog.bounds.x,y = toolRing.mainWidget.dialog.bounds.y}
        if rPos.x <= BUTTON_SIZE or rPos.y <= BUTTON_SIZE then
            rPos = MAIN_DLG_POSITION
        end
        local tr = {pos = rPos, size = toolRing.buttonSize, dist = toolRing.ringDistance, childs = {}}
        for _, wData in ipairs(toolRing.childWidgets) do
        local wgd = {color = nil, tool = nil}
            if wData.color ~=nil then
                wgd.color = {r = wData.color.red, g = wData.color.green, b = wData.color.blue, a= wData.color.alpha}
            end
            if wData.icon ~=nil then
                wgd.tool = string.sub( wData.icon, 6 )
            end
            table.insert(tr.childs,wgd)
        end
        table.insert(ringList, tr)
    end
    return ringList
end

function InitToolRing(toolRingList)
    -- create a new entrance if all tool rings are loaded
    if IS_LOADED then
        local toolRing = ToolRing:new(MAIN_DLG_POSITION, BUTTON_SIZE, BORDER_SIZE, RING_DISTANCE)
        table.insert( TOOL_RING_LIST, toolRing)
    end
    if not IS_LOADED then     
        for _, dataToolRing in ipairs(toolRingList) do
            local size = dataToolRing.size - BORDER_SIZE
            local pos = dataToolRing.pos
            local dist = dataToolRing.dist -- BORDER_SIZE * 2
            local childs = dataToolRing.childs
            local toolRing = ToolRing:new(pos, size, BORDER_SIZE, dist)
            toolRing.position = pos
            toolRing.childWidgets = {}
            for _, child in ipairs(childs) do
                if child.tool ~= nil then
                    toolRing:addToolWidget(child.tool)
                elseif child.color ~= nil then
                    -- color don't load see api
                    
                    local c = Color{r=child.color.r,g=child.color.g,b=child.color.b,a=child.color.a}
                    toolRing:addColorWidget(c)
                end
            end
            toolRing.mainWidget.show = false
            table.insert( TOOL_RING_LIST, toolRing)
        end
        IS_LOADED = true
    end
    -- add a first entrance if no tool ring has been created yet
    if #TOOL_RING_LIST  <= 0 then
        local toolRing = ToolRing:new(MAIN_DLG_POSITION, BUTTON_SIZE, BORDER_SIZE, RING_DISTANCE)
        table.insert( TOOL_RING_LIST, toolRing)
    end
    for _, toolRing in ipairs(TOOL_RING_LIST) do
        if not toolRing.mainWidget.show then
            toolRing:showMainWidget()
            toolRing.mainWidget.show = true
        end
    end
end