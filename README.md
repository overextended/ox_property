# ox_property

Property system for [ox_core](https://github.com/overextended/ox_core), not an apartment system. Intended as a framework to support other scripts in creating intractable components(zones and points) tied to a centralised permission system while providing some basic locations and capabilities.

## Permissions

Permissions and ownership for each property are managed at it's  management zone and will update in real time. Each can be owned by a player and/or group, providing full access to the property for the owning player and the owning group's top ranked players through permission level 1.

Permissions are flexible and highly customisable. Additional levels can be created and provide a custom level of access to each component. Membership for each level can be limited to individual players, a grade threshold of any group or opened to everyone.

## Extension

Adding more properties is a simple case of creating a new property config file as a data file of any resource and declaring that file as ox_property_data in the manifest. If started after ox_property, the data files will automatically be loaded on resource start. Additional component types and the actions triggered by their use can be created via exports. [ox_vehicledealer](https://github.com/overextended/ox_vehicledealer) is a good example of this process.

## Properties included

### Houses

Each readily available vanilla house is preconfigured with parking, wardrobes and stashes where appropriate.

### Parking

Various public car parks.

## Built in components

### Management

One per property, manage permissions and ownership.

### Parking

Store, retrieve, recover and transfer vehicles between different parking locations.

### Stashes

Standard stashes through ox_inventory.

### Wardrobe

Manage personal outfits and outfits specific to the current location. WIP, will probably get a rewrite.

## Todo

- additional property config (help wanted if you are able to follow often vague requirements and take criticism)
- teleport component
- shops, crafting
- ox_doorlock integration
- property info display
