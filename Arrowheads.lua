-- Helper function to register UI actions
local function registerArrowheadAction(menu, callback, accelerator, toolbarId, iconName)
    app.registerUi({
        menu = menu,
        callback = callback,
        accelerator = accelerator,
        toolbarId = toolbarId,
        iconName = iconName
    })
end

-- Initialize UI with all arrowhead insertion options
function initUi()
    registerArrowheadAction("Insert Arrowhead At Start Point", "insertArrowheadStart", "<Control><Alt>1", "insertArrowheadStart", "arrowheadStart")
    registerArrowheadAction("Insert Arrowhead At Middle Point", "insertArrowheadMiddle", "<Control><Alt>2", "insertArrowheadMiddle", "arrowheadMiddle")
    registerArrowheadAction("Insert Arrowhead At End Point", "insertArrowheadEnd", "<Control><Alt>3","insertArrowheadEnd", "arrowheadEnd" )
    registerArrowheadAction("Insert Arrowhead At Both Ends", "insertArrowheadBoth", "<Control><Alt>4", "insertArrowheadBoth", "arrowheadBoth") 
    registerArrowheadAction("Insert Arrowhead Like Arrow", "insertArrowheadLikeArrow", "<Control><Alt>5", "insertArrowheadLikeArrow", "arrowheadArrow") 
end

-- General function to insert an arrowhead at a specified position
local function createArrowhead(stroke, position, rotate180)
    local width = stroke.width-- or 2.26
    local pressureArray = stroke.pressure or {}
    local x, y, prevX, prevY, pressure

    if position == "start" then
        x, y = stroke.x[1], stroke.y[1]
        prevX, prevY = stroke.x[2] or stroke.x[#stroke.x], stroke.y[2] or stroke.y[#stroke.y] -- For line having more than two points, the next/previous will be the next or previous point, for straight line (only two points) it should be the other point
        pressure = pressureArray[5] or width -- For any line it will pick pressure of the fifth point as the pressure may very low at the start. For straight line and spline there is no pressure value and it will pick width.
    elseif position == "end" then
        x, y = stroke.x[#stroke.x], stroke.y[#stroke.y]
        prevX, prevY = stroke.x[#stroke.x - 1] or stroke.x[1], stroke.y[#stroke.y - 1] or stroke.y[1]-- For line having more than two points, the next/previous will be the next or previous point, for straight line (only two points) it should be the other point
        pressure = pressureArray[#pressureArray - 5] or width -- For any line it will pick pressure of the fifth point from the last as the pressure may very low at the start. For straight line and spline there is no pressure value and it will pick width.
    elseif position == "middle" then
        x, y, prevX, prevY, pressure = calculateMidpoint(stroke, width, pressureArray) -- It will pick value from this function as for the midpoint there are little more calculatio
    end

    local deltaX, deltaY = x - prevX, y - prevY
    local angle = math.atan2(deltaY, deltaX) + (rotate180 and math.pi or 0)
    local adjustedWidth = math.min(pressure, width) -- Width of the arrowhead is linked to the pressure for beter presentation
    local scaleFactor = (adjustedWidth > 2.26) and (0.75 * adjustedWidth / 2.26) or 1 -- also increases its size if line width is more tha 2.26

    local arrowhead = createRotatedArrowhead(x, y, angle, scaleFactor, adjustedWidth, stroke)
    app.addStrokes { strokes = { arrowhead, allowUndoRedoAction = "grouped" }}
end

-- Function to calculate midpoint for curved strokes
function calculateMidpoint(stroke, width, pressureArray)
    local x1, y1 = stroke.x[1], stroke.y[1]
    local x2, y2 = stroke.x[#stroke.x], stroke.y[#stroke.y]
    local centerX, centerY = (x1 + x2) / 2, (y1 + y2) / 2

    -- If it's a straight line, set midpoint directly without closest point calculation
    if #stroke.x == 2 then
        local x, y = centerX, centerY
        local prevX, prevY = x1, y1
        local pressure = pressureArray[1] or width
        return x, y, prevX, prevY, pressure
    end

    -- For curved strokes, find the point (on the stroke) closest to the center of the imaginary line joining the first and last points of the curvved stroke
    local closestIndex, minDistance = 1, math.huge
    for i = 1, #stroke.x do
        if stroke.x[i] and stroke.y[i] then
            local distance = math.sqrt((stroke.x[i] - centerX)^2 + (stroke.y[i] - centerY)^2)
            if distance < minDistance then
                minDistance = distance
                closestIndex = i
            end
        end
    end

    local x, y = stroke.x[closestIndex], stroke.y[closestIndex]
    local prevX, prevY = stroke.x[closestIndex - 1] or x2, stroke.y[closestIndex - 1] or y2
    local pressure = pressureArray[closestIndex] or width

    return x, y, prevX, prevY, pressure
end


-- Function to create and rotate arrowhead based on angle and scale (first create arrowhead pointing towards right, then rotate)
function createRotatedArrowhead(x, y, angle, scaleFactor, width, stroke)
    local arrowhead = {
        x = {x - 5 * scaleFactor, x + 5 * scaleFactor, x - 5 * scaleFactor}, -- the centre of the arrowhead is at the (x,y) ponint, not the tip because for rotation it is essential
        y = {y + 5 * scaleFactor, y, y - 5 * scaleFactor},
        width = width,
        tool = stroke.tool or "pen",
        color = stroke.color or 0xff0000,
        capStyle = stroke.capStyle or "round",
        lineStyle = stroke.lineStyle,
    }

    for i = 1, #arrowhead.x do
        local x_offset = arrowhead.x[i] - x
        local y_offset = arrowhead.y[i] - y
        arrowhead.x[i] = x + (x_offset * math.cos(angle) - y_offset * math.sin(angle))
        arrowhead.y[i] = y + (x_offset * math.sin(angle) + y_offset * math.cos(angle))
    end

     -- Shift the arrowhead center towards the endpoint by 5 points after rotation (as the center is placed at (x,y) the arrowhead should be moved to the insertion point after rotation by 5 points)
     local offsetX = -5 * math.cos(angle)
     local offsetY = -5 * math.sin(angle)
     for i = 1, #arrowhead.x do
         arrowhead.x[i] = arrowhead.x[i] + offsetX
         arrowhead.y[i] = arrowhead.y[i] + offsetY
     end

    return arrowhead
end

-- Functions for specific positions
function insertArrowheadStart() 
    createArrowhead(app.getStrokes("selection")[1], "start", false); -- local function createArrowhead(stroke, position, rotate180)
    app.refreshPage() 
end
function insertArrowheadMiddle() 
    createArrowhead(app.getStrokes("selection")[1], "middle", false); 
    app.refreshPage() 
end
function insertArrowheadEnd() 
    createArrowhead(app.getStrokes("selection")[1], "end", false); 
    app.refreshPage() 
end
function insertArrowheadBoth() 
    local stroke = app.getStrokes("selection")[1]
    createArrowhead(stroke, "start", false)
    createArrowhead(stroke, "end", false)
    app.refreshPage()
end
function insertArrowheadLikeArrow() 
    local stroke = app.getStrokes("selection")[1]
    createArrowhead(stroke, "start", true)
    createArrowhead(stroke, "end", false)
    app.refreshPage()
end
