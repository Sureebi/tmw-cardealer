# TMW Car Dealership

A comprehensive gang/job-based car dealership system for FiveM QBCore/Qbox servers with physical showroom vehicles, test drives, and commission-based sales.

## Features

- **Physical Showroom**: 7 vehicles displayed in the showroom that can be changed dynamically
- **50 Vehicles Available**: 7 physical + 43 menu-only vehicles for sale
- **Test Drive System**: Dealers can give test drives to nearby players (10m radius)
- **Commission System**: Configurable commission for sellers (default 10%)
- **Gang/Job Integration**: Supports both gang and job-based access control
- **Renewed-Banking Integration**: Money flows to gang/job accounts
- **Nearby Player Selection**: Interactive menus to select nearby players for sales and test drives
- **Vehicle Protection**: Showroom vehicles are locked, invincible, and cannot be entered
- **Client-Side Spawning**: Optimized vehicle spawning with proper model loading
- **Synchronized State**: All players see the same vehicles in the showroom

## Dependencies

- [qb-core](https://github.com/qbcore-framework/qb-core) or [qbx_core](https://github.com/Qbox-project/qbx_core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [oxmysql](https://github.com/overextended/oxmysql)
- [Renewed-Banking](https://github.com/Renewed-Scripts/Renewed-Banking) (optional, for gang account integration)

## Installation

1. Download and extract the resource to your `resources` folder
2. Rename the folder to `car_showroom` (or your preferred name)
3. Add `ensure car_showroom` to your `server.cfg`
4. Configure `config.lua` to match your server setup
5. If using gang system, create the gang account in Renewed-Banking:
   ```
   /createaccount [gang_name]
   ```
6. Restart your server

## Configuration

### Basic Settings (`config.lua`)

```lua
Config.DealerJob = 'radko'        -- Job/Gang name that can sell vehicles
Config.UseGang = true              -- true = gang system, false = job system
Config.Commission = 0.10           -- 10% commission for sellers
```

### Showroom Vehicles

The first 7 vehicles with valid coordinates will be displayed physically in the showroom:

```lua
{ model = 'gbmochi', price = 105000, coords = vector4(-1256.94, -366.31, 36.18, 83.10), zOffset = 0.0, label = 'Mochi' }
```

Vehicles with `coords = vector4(0, 0, 0, 0)` are available for sale but not displayed physically.

### Locations

- **Showroom**: Legion Square area
- **Test Drive Spots**: 13 parking spots near the showroom
- **Delivery Location**: Where purchased vehicles spawn

## Usage

### For Dealers (Job/Gang Members)

1. **View Catalog**: Click on any showroom vehicle to browse all available cars
2. **Change Display**: Select a different vehicle from the catalog to display it
3. **Test Drive**: 
   - Click "Test Drive" on a showroom vehicle
   - Select a nearby player from the menu
   - Player receives a 2-minute test drive
4. **Sell Vehicle**:
   - Click "Sell Car" on a showroom vehicle
   - Select a nearby player from the menu
   - Confirm the sale
   - Buyer must have sufficient bank balance
   - Seller receives commission in cash
   - Gang/Job receives remaining amount in Renewed-Banking

### For Customers

1. **Browse**: Anyone can view the catalog and see prices
2. **Test Drive**: Receive test drive from dealer (2 minutes, returns to original location)
3. **Purchase**: Receive vehicle at delivery location with ownership and keys

## Features in Detail

### Vehicle Protection

Showroom vehicles have:
- "SHOWROOM" license plate
- Locked doors (cannot be entered)
- Invincible and frozen
- Perfect condition (no damage/smoke)
- Normal tires (not bulletproof)
- Auto-eject if player tries to enter

Test drive and purchased vehicles use different plates and are NOT protected.

### Money Flow

```
Buyer (Bank) → Gang Account (Renewed-Banking) + Seller Commission (Cash)
```

Example: $100,000 vehicle with 10% commission
- Buyer pays: $100,000 from bank
- Gang receives: $90,000 in Renewed-Banking
- Seller receives: $10,000 in cash

### Nearby Player System

Both test drives and sales show a menu with:
- Player name (first + last)
- Player ID
- Distance in meters
- Only players within 10m radius

### Database Integration

Purchased vehicles are automatically saved to `player_vehicles` table with:
- Owner citizenid
- Vehicle model and hash
- Vehicle properties (mods, colors, etc.)
- License plate
- State (0 = out)

## Commands

- `/nearby` - Check nearby players (dealer only, shows list in notification)

## Troubleshooting

### Vehicles not spawning
- Check console for model loading errors
- Increase timeout in client.lua if using heavy vehicle mods
- Ensure vehicle models are in your server

### Money not going to gang account
- Verify Renewed-Banking is started
- Create gang account: `/createaccount [gang_name]`
- Check server console for error messages

### Players can enter showroom vehicles
- Check that vehicle plate is "SHOWROOM"
- Verify protection thread is running
- Test drive vehicles use "TEST" plate (intentionally not protected)

### Test drive/sales not working
- Ensure players are within 10m radius
- Check that dealer has correct job/gang
- Verify ox_lib and ox_target are running

## Credits

- **Vehicle Models**: GB Vehicles Pack
- **Framework**: QBCore/Qbox
- **Libraries**: ox_lib, ox_target, oxmysql
- **Banking**: Renewed-Banking

## License

This project is open source and available under the MIT License.

## Support

For issues, questions, or suggestions, please open an issue on GitHub.
