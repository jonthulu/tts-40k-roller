
lastAttack = nil
dieLimit = 300

function resetLastAttack()
    lastAttack = {
      state = nil,
      hitSkill = nil,
      hitValues = nil,
      hitResults = nil,
      hitReroll = nil,
      woundSkill = nil,
      woundValues = nil,
      woundResults = nil,
      woundReroll = nil,
      saveSkill = nil,
      saveValues = nil,
      saveResults = nil,
      ignoreSkill = nil,
      ignoreValues = nil,
      ignoreResults = nil
    }
end

resetLastAttack()

function onChat(message, player)
    local isHitRoll = string.find(message, 'hit ')
    if isHitRoll == 1 then
        onHitRoll(message, player)
        return
    end

    local isWoundRoll = string.find(message, 'wound ')
    if isWoundRoll == 1 then
        onWoundRoll(message, player)
        return
    end

    local isSaveRoll = string.find(message, 'save ')
    if isSaveRoll == 1 then
        onSaveRoll(message, player)
        return
    end

    local isIgnoreWoundRoll = string.find(message, 'ignore ')
    if isIgnoreWoundRoll == 1 then
        onIgnoreWoundRoll(message, player)
        return
    end

    local isReRoll = string.find(message, 'reroll ')
    if isReRoll == 1 then
        onReRoll(message, player)
        return
    end
end

function onHitRoll(message, player)
    local skill, dieCount = string.match(message, 'hit ([2-6])+? (%d+d?[36]?)')
    if isEmpty(skill) or isEmpty(dieCount) then
        printError('Command: hit *Skill *Attacks')
        printError('  *Skill - 2, 3, 4, 5, or 6 - The value that designates what is needed to hit.')
        printError('  *Attacks - The number of attacks (integer).')
        return
    end

    -- TODO: Add support for dice dieCount (3d6 or 5d3) (already in the string.match)

    if isOverDieLimit(dieCount) then
        return
    end

    resetLastAttack()

    local values, results = throwD6(dieCount, skill)

    -- Output the hit roll numbers in case a rule will activate on a number.
    printDieValues('Hit rolls: ', values, player)

    local hitOutput = string.format("%s Hits  |  %s Misses", results.hits, results.misses)
    printToAll(hitOutput, playerToPrintColor(player))

    lastAttack.state = 'hit'
    lastAttack.hitSkill = skill
    lastAttack.hitValues = values
    lastAttack.hitResults = results
end

function onWoundRoll(message, player)
    local skill, dieCount = string.match(message, 'wound ([2-6])+? ?(%d*)')
    if isEmpty(skill) then
        printError('Command: wound *Skill [*Hits]')
        printError('  *Skill - 2, 3, 4, 5, or 6 - The value that designates what is needed to wound.')
        printError('  *Hits - Optional - The number of hits (integer). This is not needed following a hit command.')
        return
    end

    if isEmpty(dieCount) then
        if lastAttack.state ~= 'hit' then
            printError('You must provide the number of dice unless rolling Wound after a Hit roll.')
            return
        end

        dieCount = lastAttack.hitResults.hits
    else
        resetLastAttack()
    end

    if isOverDieLimit(dieCount) then
        return
    end

    local values, results = throwD6(dieCount, skill)

    -- Output the wound roll numbers in case a rule will activate on a number.
    printDieValues('Wound rolls: ', values, player)

    local woundOutput = string.format("%s Wounds  |  %s Misses", results.hits, results.misses)
    printToAll(woundOutput, playerToPrintColor(player))

    lastAttack.state = 'wound'
    lastAttack.woundSkill = skill
    lastAttack.woundValues = values
    lastAttack.woundResults = results
end

function onSaveRoll(message, player)
    local skill, dieCount = string.match(message, 'save ([2-6])+? ?(%d*)')
    if isEmpty(skill) then
        printError('Command: save *Skill [*Wounds]')
        printError('  *Skill - 2, 3, 4, 5, or 6 - The value that designates what is needed to save.')
        printError('  *Wounds - Optional - The number of wounds (integer). This is not needed following a wound command.')
        return
    end

    if isEmpty(dieCount) then
        if lastAttack.state ~= 'wound' then
            printError('You must provide the number of dice unless rolling Save after a Wound roll.')
            return
        end

        dieCount = lastAttack.woundResults.hits
    else
        resetLastAttack()
    end

    if isOverDieLimit(dieCount) then
        return
    end

    local values, results = throwD6(dieCount, skill)

    -- Output the save roll numbers in case a rule will activate on a number.
    printDieValues('Save rolls: ', values, player)

    local saveOutput = string.format("%s Saved  |  %s Unsaved", results.hits, results.misses)
    printToAll(saveOutput, playerToPrintColor(player))

    lastAttack.state = 'save'
    lastAttack.saveSkill = skill
    lastAttack.saveValues = values
    lastAttack.saveResults = results
end

function onIgnoreWoundRoll(message, player)
    local skill, dieCount = string.match(message, 'ignore ([2-6])+? x(d?%d)')
    local skillAlt, dieCountAlt = string.match(message, 'ignore ([2-6])+? ?(%d*)')

    if isEmpty(skill) and isEmpty(skillAlt) then
        printError('Command: ignore *Skill [*Multiplier] or [*Damage]')
        printError('  *Skill - 2, 3, 4, 5, or 6 - The value that designates what is needed to ignore the wound.')
        printError('  *Multiplier - Optional - Must be prefixed with an x. This will multiply the previous wound/unsaved value by the given value to determine damage.')
        printError('  *Damage - Optional - The amount of damage (integer). This is not needed following a wound or save command.')
        return
    end

    -- TODO: Add support for dice Multiplier (xd3 or xd6) (already in the string.match)

    if not isEmpty(skill) then
        if lastAttack.state ~= 'wound' and lastAttack.state ~= 'save' then
            printError('You can not provide a multiplier unless rolling Ignore Wounds after a Wound roll or Save roll.')
            return
        end

        if lastAttack.state == 'wound' then
            dieCount = lastAttack.woundResults.hits * dieCount
        else
            dieCount = lastAttack.saveResults.hits * dieCount
        end
    else
        if isEmpty(dieCount) then
            if lastAttack.state ~= 'wound' and lastAttack.state ~= 'save' then
                printError('You must provide the number of dice unless rolling Ignore Wounds after a Wound roll or Save roll.')
                return
            end

            if lastAttack.state == 'wound' then
                dieCount = lastAttack.woundResults.hits
            else
                dieCount = lastAttack.saveResults.hits
            end
        else
            dieCount = dieCountAlt

            resetLastAttack()
        end

        skill = skillAlt
    end

    if isOverDieLimit(dieCount) then
        return
    end

    local values, results = throwD6(dieCount, skill)

    -- Output the ignore wound roll numbers in case a rule will activate on a number.
    printDieValues('Ignore Wound rolls: ', values, player)

    local saveOutput = string.format("%s Ignored  |  %s Damage Taken", results.hits, results.misses)
    printToAll(saveOutput, playerToPrintColor(player))

    lastAttack.state = 'ignore'
    lastAttack.ignoreSkill = skill
    lastAttack.ignoreValues = values
    lastAttack.ignoreResults = results
end

function onReroll(message, player)
    local reRollValue = string.match(message, 'reroll ([1%*])')
    if isEmpty(reRollValue) then
        printError('Command: reroll *Values')
        printError('  *Values - 1 or * - 1 re-rolls all 1s; * re-rolls all fails.')
        return
    end

    local previousValues = nil
    local previousSkill = nil
    if lastAttack.state == 'hit' then
        previousValues = {table.unpack(lastAttack.hitValues)}
        previousSkill = lastAttack.hitSkill
    elseif lastAttack.state == 'wound' then
        previousValues = {table.unpack(lastAttack.woundValues)}
        previousSkill = lastAttack.woundSkill
    else
        printError('You can only re-roll following a Hit or Wound roll.')
        return
    end

    local dieCount = 0
    if reRollValue == '1' then
        dieCount = previousValues['1']
        previousValues['1'] = 0
    else
        for i=1,previousSkill do
            dieCount = dieCount + previousValues[i]
            previousValues[i] = 0
        end
    end

    local combinedValues, combinedResults = reRollD6(dieCount, previousSkill, previousValues)

    if lastAttack.state == 'hit' then
        -- Output the re-rolled hit roll numbers in case a rule will activate on a number.
        printDieValues('Rerolled Hits: ', combinedValues, player)

        local hitOutput = string.format("%s Hits  |  %s Misses", combinedResults.hits, combinedResults.misses)
        printToAll(hitOutput, playerToPrintColor(player))

        lastAttack.hitReroll = newValues
        lastAttack.hitValues = combinedValues
        lastAttack.hitResults = combinedResults
    elseif lastAttack.state == 'wound' then
        -- Output the re-rolled wound roll numbers in case a rule will activate on a number.
        printDieValues('Rerolled Wounds: ', combinedValues, player)

        local woundOutput = string.format("%s Wounds  |  %s Misses", combinedResults.hits, combinedResults.misses)
        printToAll(woundOutput, playerToPrintColor(player))

        lastAttack.woundReroll = newValues
        lastAttack.woundValues = combinedValues
        lastAttack.woundResults = combinedResults
    end
end

function throwD6(dieCount, skill)
    local thrownDice = {0, 0, 0, 0, 0, 0}
    local results = {hits = 0, misses = 0}
    local safeSkill = tonumber(skill)

    for i=1,dieCount do
        local d = math.floor(math.random() * 6 + 1)

        thrownDice[d] = thrownDice[d] + 1

        if not isEmpty(skill) then
            if d >= safeSkill then
                results.hits = results.hits + 1
            else
                results.misses = results.misses + 1
            end
        end
    end

    return thrownDice, results
end

function reRollD6(dieCount, skill, previousValues)
    local thrownDice = {0, 0, 0, 0, 0, 0}
    local results = {hits = 0, misses = 0}
    local safeSkill = tonumber(skill)

    for i=1, #thrownDice do
        if i >= safeSkill then
            thrownDice[i] = previousValues[i]
        end
    end

    for i=1,dieCount do
        local d = math.floor(math.random() * 6 + 1)

        thrownDice[d] = thrownDice[d] + 1

        if not isEmpty(skill) then
            if d >= safeSkill then
                results.hits = results.hits + 1
            else
                results.misses = results.misses + 1
            end
        end
    end

    for i=1, #thrownDice do
        if thrownDice[i] >= safeSkill then
            results.hits = results.hits + 1
        else
            results.misses = results.misses + 1
        end
    end

    return thrownDice, results
end

function isOverDieLimit(dieCount)
    if tonumber(dieCount) > dieLimit then
        -- Cannot roll more than dieLimit die
        printToAll(string.format("Cannot roll more than %s die.", dieLimit))
        return true
    end

    return false
end

function playerToPrintColor(player)
    return player
end

function printError(message)
    print(message)
end

function printDieValues(prefix, dieValues, player)
    local output = ''

    for i=1, #dieValues do
        if dieValues[i] ~= 0 then
            if i ~= 1 then
                output = output .. "  |  "
            end

            output = output .. i .. ": " .. dieValues[i]
        end
    end

    printToAll(prefix .. output, playerToPrintColor(player))
end

function isEmpty(item)
    return item == nil or item == ''
end
